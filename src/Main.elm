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
  }

type Msg =
  AnimationFrame Time
  | CanvasMsg Canvas.Msg
  | PhoenixMsg (Phoenix.Socket.Msg Msg)
  | ReceiveChatMessage JE.Value
  | JoinedChannel JE.Value

-- INIT

init : (Model, Cmd Msg)
init =
  let
    (phxSocket, phxCmd) = initPhoenix
    (canvas, canvasCmd) = Canvas.init
  in
    { phxSocket = phxSocket
    , canvas = canvas }
    ! [Cmd.map CanvasMsg canvasCmd, phxCmd]


initPhoenix : (Phoenix.Socket.Socket Msg, Cmd Msg)
initPhoenix =
  initPhxSocket
    |> joinChannel

socketServer : String
socketServer =
  "ws://localhost:4000/socket/websocket"

initPhxSocket : Phoenix.Socket.Socket Msg
initPhxSocket =
  Phoenix.Socket.init socketServer
    |> Phoenix.Socket.withDebug
    |> Phoenix.Socket.on "join" "room:lobby" JoinedChannel
    |> Phoenix.Socket.on "new:msg" "room:lobby" ReceiveChatMessage

joinChannel : Phoenix.Socket.Socket Msg -> (Phoenix.Socket.Socket Msg, Cmd Msg)
joinChannel phxSocket =
  let
    channel =
      Phoenix.Channel.init "room:lobby"
    (newPhxSocket, phxCmd) =
      Phoenix.Socket.join channel phxSocket
  in
    (newPhxSocket, Cmd.map PhoenixMsg phxCmd)


-- UPDATE

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    AnimationFrame delta ->
      let
        newCanvas = Canvas.updateAnimationFrame model.canvas
        --If this updated produced a line, then create commands to draw
        --the line on the local canvas and remote clients
        (newModel, cmd) =
          case newCanvas.tileLines of
            Just tileLines ->
              let
                drawCmds = List.map drawLine tileLines
                (phxSocket, phxCmd) = sendDraw model.phxSocket tileLines
              in
                { model | phxSocket = phxSocket, canvas = newCanvas }
                ! (drawCmds ++ [phxCmd])
            Nothing ->
              if newCanvas.viewUpdated then
                { model | canvas = { newCanvas | viewUpdated = False } }
                ! [ updateCanvas newCanvas.canvasView ]
              else
                (model, Cmd.none)

      in
        (newModel, cmd)
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
    JoinedChannel payload ->
      let
        _ = Debug.log "I joined a channel" payload
      in
        (model, Cmd.none)

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

sendDraw : Phoenix.Socket.Socket Msg -> List TileLine -> (Phoenix.Socket.Socket Msg, Cmd Msg)
sendDraw phxSocket tileLines =
  let
    payload =
      (JE.object [ ( "body", encodeTileLines tileLines ) ])
    push' =
      Phoenix.Push.init "new:msg" "room:lobby"
        |> Phoenix.Push.withPayload payload

    ( newPhxSocket, phxCmd ) =
      Phoenix.Socket.push push' phxSocket
  in
    ( newPhxSocket
    , Cmd.map PhoenixMsg phxCmd
    )

-- VIEW

canvasClass drawMode dragging =
   (if drawMode then "draw" else (if dragging then "dragging" else "drag"))

debugDivStyle =
  [("position", "absolute"), ("bottom", "50px")]

debugDiv model =
  div [ id "debug", style debugDivStyle ] [ text ("Model: " ++ (toString model.canvas.visibleTiles)) ]

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
    App.map controlToCanvas (Controls.colourPalette (model.canvas.canvasView.zoom <= 500) model.canvas.selectedDrawMode model.canvas.curColour model.canvas.lineWidth)

view : Model -> Html Msg
view model =
  div [ ]
    [ colourPaletteView model
    , canvas [ id "mycanvas", class (canvasClass model.canvas.drawMode model.canvas.mouseDown) ] []
    , debugDiv model
    ]

--SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
    [ Phoenix.Socket.listen model.phxSocket PhoenixMsg
    , Sub.map CanvasMsg (Canvas.subscriptions)
    , AnimationFrame.diffs AnimationFrame
    ]