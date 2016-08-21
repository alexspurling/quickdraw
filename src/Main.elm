module Main exposing (..)

import AnimationFrame
import Html.App as App
import Html exposing (Html, div, text, canvas)
import Html.Attributes exposing (id, style, class)

import Json.Encode as JE exposing (Value, object)
import Json.Decode as JD exposing ((:=), object2, object5, tuple2)
import Time exposing (Time)

import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push

import Canvas.Canvas as Canvas
import Canvas.Ports exposing (..)
import Canvas.Colours as Colours exposing (Colour)
import Canvas.Controls as Controls
import Canvas.Vector exposing (Position)

main =
   App.program { init = init, view = view, update = update, subscriptions = subscriptions }

type alias Model =
  { phxSocket : Phoenix.Socket.Socket Msg
  , canvas : Canvas.Model
  , frames : Int
  , fps : Int
  , time : Time
  }

type Msg =
  AnimationFrame Time
  | CanvasMsg Canvas.Msg
  | PhoenixMsg (Phoenix.Socket.Msg Msg)
  | ReceiveChatMessage JE.Value

-- INIT

init : (Model, Cmd Msg)
init =
  let
    (canvas, canvasCmd) = Canvas.init
  in
    { phxSocket = initPhxSocket
    , canvas = canvas
    , frames = 0
    , fps = 0
    , time = 0 }
    ! [Cmd.map CanvasMsg canvasCmd]

socketServer : String
socketServer =
  "ws://localhost:4000/socket/websocket"

initPhxSocket : Phoenix.Socket.Socket Msg
initPhxSocket =
  Phoenix.Socket.init socketServer
    |> Phoenix.Socket.withDebug
    |> Phoenix.Socket.on "new:msg" "room:lobby" ReceiveChatMessage


-- UPDATE

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    AnimationFrame time ->
      let
        model1 = { model | canvas = Canvas.updateAnimationFrame model.canvas }
        model2 = updateFrames time model1
        (model3, cmd) =
          model2
            |> getDrawCmd
            |> getSendDrawCmd
            |> getUpdateCanvasCmd
            |> getJoinLeaveCmd
      in
        (model3, cmd)
    CanvasMsg canvasMsg ->
        {model | canvas = Canvas.update canvasMsg model.canvas} ! []
    PhoenixMsg msg ->
      let
        ( phxSocket, phxCmd ) =
          Phoenix.Socket.update msg model.phxSocket
      in
        ( { model | phxSocket = phxSocket }
        , Cmd.map PhoenixMsg phxCmd
        )
    ReceiveChatMessage payload ->
      let
        payloadDecoder = ("body" := linesOnTilesDecoder)
        drawLineCmd =
          case JD.decodeValue payloadDecoder payload of
            Ok tileLines ->
              List.map drawLine tileLines
            Err error ->
              let
                _ = Debug.log "Failed to decode payload" error
              in
                []
      in
        model ! drawLineCmd

updateFrames : Time -> Model -> Model
updateFrames time model =
  if time - model.time > Time.second then
    { model | time = time, fps = model.frames, frames = 0 }
  else
    { model | frames = model.frames + 1 }

getDrawCmd : Model -> (Model, Cmd Msg)
getDrawCmd model =
  case model.canvas.tileLines of
    Just tileLines ->
      model ! List.map drawLine tileLines
    Nothing ->
      model ! []

getSendDrawCmd : (Model, Cmd Msg) -> (Model, Cmd Msg)
getSendDrawCmd (model, prevCmd) =
  case model.canvas.tileLines of
    Just tileLines ->
      let
        --We use fold here to build up a list of commands because the phoenix socket library always
        --returns an updated version of the socket along with the commands which we have to pass
        --to all subsequent calls
        (phxSocket, phxCmd) = List.foldl sendDraw (model.phxSocket, Cmd.none) tileLines
      in
        { model | phxSocket = phxSocket } ! [prevCmd, phxCmd]
    Nothing ->
        model ! [prevCmd]

getUpdateCanvasCmd : (Model, Cmd Msg) -> (Model, Cmd Msg)
getUpdateCanvasCmd (model, prevCmd) =
  if model.canvas.viewUpdated then
    let
      newCanvas = Canvas.updateTileDiff model.canvas
      updateCanvasCmd = updateCanvas (newCanvas.canvasView, newCanvas.tileDiff)
    in
      { model | canvas = { newCanvas | viewUpdated = False } }
      ! [prevCmd, updateCanvasCmd]
  else
    model ! [prevCmd]

sendDraw : TileLine -> (Phoenix.Socket.Socket Msg, Cmd Msg) -> (Phoenix.Socket.Socket Msg, Cmd Msg)
sendDraw tileLine (phxSocket, prevCmd) =
  let
    payload =
      (JE.object [ ( "body", encodeTileLine tileLine ) ])
    channel = (getChannelForTile tileLine.tile)
    push =
      Phoenix.Push.init "new:msg" channel
        |> Phoenix.Push.withPayload payload

    ( newPhxSocket, phxCmd ) =
      Phoenix.Socket.push push phxSocket
  in
    newPhxSocket ! [prevCmd, Cmd.map PhoenixMsg phxCmd]

getChannelForTile : Tile -> String
getChannelForTile (tileI, tileJ) =
  "tile:" ++ toString tileI ++ "-" ++ toString tileJ

getJoinLeaveCmd : (Model, Cmd Msg) -> (Model, Cmd Msg)
getJoinLeaveCmd (model, prevCmd) =
  let
    channelsToJoin = List.map getChannelForTile model.canvas.tileDiff.newTiles
    channelsToLeave = List.map getChannelForTile model.canvas.tileDiff.oldTiles
    --We use fold here to build up a list of commands because the phoenix socket library always
    --returns an updated version of the socket along with the commands which we have to pass
    --to all subsequent calls
    (phxSocket1, phxCmd1) = List.foldl joinChannel (model.phxSocket, Cmd.none) channelsToJoin
    (phxSocket2, phxCmd2) = List.foldl leaveChannel (phxSocket1, phxCmd1) channelsToLeave
  in
    { model | phxSocket = phxSocket2 } ! [prevCmd, phxCmd2]


joinChannel : String -> (Phoenix.Socket.Socket Msg, Cmd Msg) -> (Phoenix.Socket.Socket Msg, Cmd Msg)
joinChannel channelToJoin (phxSocket, prevCmd) =
  let
    channel = Phoenix.Channel.init channelToJoin
    (newPhxSocket, phxCmd) = Phoenix.Socket.join channel phxSocket
  in
    newPhxSocket ! [prevCmd, Cmd.map PhoenixMsg phxCmd]

leaveChannel : String -> (Phoenix.Socket.Socket Msg, Cmd Msg) -> (Phoenix.Socket.Socket Msg, Cmd Msg)
leaveChannel channelToLeave (phxSocket, prevCmd) =
  let
    (newPhxSocket, phxCmd) = Phoenix.Socket.leave channelToLeave phxSocket
  in
    newPhxSocket ! [prevCmd, Cmd.map PhoenixMsg phxCmd]

encodeTileLines : List TileLine -> JE.Value
encodeTileLines tileLines =
  JE.list (List.map encodeTileLine tileLines)

encodeTileLine : TileLine -> JE.Value
encodeTileLine tileLine =
  object
    [ ("line", encodeLine tileLine.line)
    , ("tile", encodeTile tileLine.tile)
    ]

encodeLine : Line -> JE.Value
encodeLine line =
  object
    [ ("lastMid", encodePosition line.lastMid)
    , ("lineFrom", encodePosition line.lineFrom)
    , ("lineMid", encodePosition line.lineMid)
    , ("colour", JE.string line.colour)
    , ("width", JE.int line.width)
    ]

encodePosition : Position -> JE.Value
encodePosition pos =
  object
    [ ("x", JE.int pos.x)
    , ("y", JE.int pos.y)
    ]

encodeTile : Tile -> JE.Value
encodeTile (i, j) =
  JE.list [JE.int i,JE.int j]

linesOnTilesDecoder : JD.Decoder (List TileLine)
linesOnTilesDecoder =
  JD.list tileLineDecoder


tileLineDecoder : JD.Decoder TileLine
tileLineDecoder =
  object2 TileLine
    ("line" := lineDecoder)
    ("tile" := tileDecoder)

lineDecoder : JD.Decoder Line
lineDecoder =
  object5 Line
    ("lastMid" := positionDecoder)
    ("lineFrom" := positionDecoder)
    ("lineMid" := positionDecoder)
    ("colour" := JD.string)
    ("width" := JD.int)

positionDecoder : JD.Decoder Position
positionDecoder =
  object2 Position
    ("x" := JD.int)
    ("y" := JD.int)

tileDecoder : JD.Decoder Tile
tileDecoder =
  tuple2 (,) JD.int JD.int

-- VIEW

canvasClass drawMode dragging =
   (if drawMode then "draw" else (if dragging then "dragging" else "drag"))

debugDivStyle =
  [("position", "absolute"), ("bottom", "50px")]

debugDiv model =
  div [ id "debug", style debugDivStyle ] [ text ("Model: " ++ (toString model.canvas.mouse)) ]

fpsDiv model =
  div [ id "fps", style [("position", "absolute"), ("top", "20px"), ("right", "20px")] ] [ text ("Fps: " ++ (toString model.fps)) ]

colourPaletteView model =
  let
    controlToCanvas : Controls.Msg -> Msg
    controlToCanvas controlMsg =
      case controlMsg of
        Controls.ColourSelected colour ->
          CanvasMsg (Canvas.ColourSelected colour)
        Controls.LineWidthSelected width ->
          CanvasMsg (Canvas.LineWidthSelected width)
        Controls.ToggleDrawMode ->
          CanvasMsg (Canvas.ToggleDrawMode)
  in
    App.map controlToCanvas (Controls.colourPalette (model.canvas.canvasView.zoom <= 5000) model.canvas.selectedDrawMode model.canvas.curColour model.canvas.lineWidth)

view : Model -> Html Msg
view model =
  div [ ]
    [ colourPaletteView model
    , fpsDiv model
    , canvas [ id "mycanvas", class (canvasClass model.canvas.drawMode model.canvas.mouseDown) ] []
    , debugDiv model
    ]

--SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
    [ Phoenix.Socket.listen model.phxSocket PhoenixMsg
    , Sub.map CanvasMsg (Canvas.subscriptions)
    , AnimationFrame.times AnimationFrame
    ]