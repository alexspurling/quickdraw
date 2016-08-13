module Main exposing (..)

import Html.App as App
import Html exposing (Html, button, div, text, h1, canvas, img)
import Html.Attributes exposing (id, height, width, style, src, class)
import Html.Events exposing (onClick)

import Json.Encode as JE exposing (Value, object)
import Json.Decode as JD exposing ((:=), object2, object5)
import Mouse exposing (Position)

import Svg exposing (svg, circle)
import Svg.Attributes exposing (version, viewBox, fill, x, y, cx, cy, r)

import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push

import Canvas.Canvas as Canvas
import Canvas.Ports exposing (..)
import Canvas.Colours as Colours exposing (Colour)

main =
   App.program { init = init, view = view, update = update, subscriptions = subscriptions }

type alias Model =
  { phxSocket : Phoenix.Socket.Socket Msg
  , canvas : Canvas.Model
  }

type Msg =
  CanvasMsg Canvas.Msg
  | PhoenixMsg (Phoenix.Socket.Msg Msg)
  | ReceiveChatMessage JE.Value

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
  "ws://localhost:4000/socket/websocket?username=quickdraw"

initPhxSocket : Phoenix.Socket.Socket Msg
initPhxSocket =
  Phoenix.Socket.init socketServer
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
    CanvasMsg canvasMsg ->
      let
        (newCanvas, canvasCmd, lineToDraw) = Canvas.update canvasMsg model.canvas
        --If this updated produced a line, then create a phxCmd to send
        --the line to the server
        (phxSocket, phxCmd) =
          case lineToDraw of
            Just line ->
              sendDraw model.phxSocket line
            Nothing ->
              (model.phxSocket, Cmd.none)
      in
        {model | canvas = newCanvas} ! [Cmd.map CanvasMsg canvasCmd, phxCmd]
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
        payloadDecoder = ("body" := lineDecoder)
        drawLineCmd =
          case JD.decodeValue payloadDecoder payload of
            Ok line -> drawLine line
            Err error ->
              let
                _ = Debug.log "Failed to decode payload" error
              in
                Cmd.none
      in
        (model, drawLineCmd)


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

sendDraw : Phoenix.Socket.Socket Msg -> Line -> (Phoenix.Socket.Socket Msg, Cmd Msg)
sendDraw phxSocket line =
  let
    payload =
      (JE.object [ ( "body", encodeLine line ) ])

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

canvasDivStyle =
  [ ("position", "relative" ) ]

colourStyle index colour selected =
  let
    --Adjust the position up and to the left by 1 pixel to account for
    --the extra width of the border when colour is selected
    posAdjustment = if selected then 1 else 0
    left = 20 + (index % 10 * 30) - posAdjustment
    top = 20 + (index // 10 * 30) - posAdjustment
    border = if selected then "1px solid " ++ colour else ""
    borderRadius = if selected then "2px" else ""
  in
    [ ("width", "25px")
    , ("height", "25px")
    , ("background-color", colour)
    , ("position", "absolute")
    , ("left", (toString left) ++ "px")
    , ("top", (toString top) ++ "px")
    , ("border", border)
    , ("border-radius", borderRadius)
    ]

colourPicker curColour index colour =
  let
    selected = curColour == colour
  in
    div
      [ style (colourStyle index (Colours.toHex colour) selected)
      , onClick (CanvasMsg (Canvas.ColourSelected colour)) ] []

pencilSizeImage colour size =
  svg
    [ version "1.1", x "0", y "0", viewBox "0 0 50 50" ]
    [ circle [fill (Colours.toHex colour), cx "25", cy "25", r (toString size)] [] ]

pencilStyle index selected =
  let
    posAdjustment = if selected then 1 else 0
    left = 20 + (index % 10 * 30) - posAdjustment
    top = 80 - posAdjustment
    border = if selected then "1px solid #ccc" else ""
    borderRadius = if selected then "2px" else ""
  in
    [ ("width", "25px")
    , ("height", "25px")
    , ("position", "absolute")
    , ("left", (toString left) ++ "px")
    , ("top", (toString top) ++ "px")
    , ("border", border)
    , ("border-radius", borderRadius)
    ]

pencilSize curColour curLineWidth index size =
  let
    selected = size == curLineWidth
  in
    div
      [ style (pencilStyle index selected), onClick (CanvasMsg (Canvas.PencilSizeSelected size)) ] [ pencilSizeImage curColour size ]

eraserStyle =
  [ ("width", "25px")
  , ("height", "25px")
  , ("position", "absolute")
  , ("left", "110px")
  , ("top", "80px") ]

eraser =
  div [ style eraserStyle, onClick (CanvasMsg (Canvas.ColourSelected Colours.White) ) ]
      [ img [ src "eraser.svg", width 25, height 25 ] [] ]

drawDragStyle =
  [ ("width", "25px")
  , ("height", "25px")
  , ("position", "absolute")
  , ("left", "140px")
  , ("top", "80px") ]

drawDrag drawMode =
  div [ style drawDragStyle, onClick (CanvasMsg Canvas.ToggleDrawMode) ]
    [ img [ src (if drawMode then "drag.svg" else "pencil.svg"), width 25, height 25 ] [] ]

colourPalette visible selectedDrawMode curColour curLineWidth =
  let
    divstyle =
      if visible then
        [ ("opacity", "1"), ("transition", "opacity 1s") ]
      else
        [ ("opacity", "0"), ("transition", "opacity 1s") ]
  in
    div [ style divstyle ]
      ((List.indexedMap (colourPicker curColour) Colours.allColours) ++
      (List.indexedMap (pencilSize curColour curLineWidth) [5, 10, 22]) ++
      [ eraser
      , drawDrag selectedDrawMode]
      )

canvasClass drawMode dragging =
   (if drawMode then "draw" else (if dragging then "dragging" else "drag"))

debugDivStyle =
  [("position", "absolute"), ("bottom", "50px")]

debugDiv model =
  div [ id "debug", style debugDivStyle ] [ text ("Model: " ++ (toString model.canvas.pencil)) ]

view : Model -> Html Msg
view model =
  div [ ]
    [ colourPalette (model.canvas.zoom <= 500) model.canvas.selectedDrawMode model.canvas.curColour model.canvas.lineWidth
    , canvas [ id "mycanvas", class (canvasClass model.canvas.drawMode model.canvas.drag.dragging) ] []
    , debugDiv model
    ]

--SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
    [ Phoenix.Socket.listen model.phxSocket PhoenixMsg
    , Sub.map CanvasMsg (Canvas.subscriptions model.canvas)
    ]