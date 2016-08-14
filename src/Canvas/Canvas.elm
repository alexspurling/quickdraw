module Canvas.Canvas exposing (..)

import AnimationFrame
import Collage
import Element
import Mouse exposing (Position)
import Time exposing (Time)

import Canvas.Ports exposing (..)
import Canvas.Drag as Drag
import Canvas.Mouse as Mouse
import Canvas.Colours as Colours exposing (Colour)

-- MODEL

type alias Model =
  { mouse : Mouse.Model
  , mouseDown : Bool
  , curColour : Colour
  , zoom : Int
  , drawMode : Bool
  , selectedDrawMode : Bool
  , drag : Drag.Model
  , lineWidth : Int
  }

init : (Model, Cmd Msg)
init =
  ( { mouse = Mouse.init
  , mouseDown = False
  , curColour = Colours.Black
  , zoom = 0
  , drawMode = True
  , selectedDrawMode = True
  , drag = Drag.init
  , lineWidth = 10 }
  , loadCanvas () )


-- UPDATE

type Msg = CanvasMouseMoved MouseMovedEvent
  | CanvasMouseDown Position
  | CanvasMouseUp
  | ColourSelected Colour
  | Zoom ZoomAmount
  | ToggleDrawMode
  | LineWidthSelected Int

type AnimationMsg =
  AnimationFrame Time

updateAnimationFrame : AnimationMsg -> Model -> (Model, Cmd Msg, Maybe Line)
updateAnimationFrame msg model =
  case msg of
    AnimationFrame delta ->
      if model.mouseDown then
        if (not model.drawMode) && model.drag.dragging then
          --Adjust cur pos
          (model, moveCanvas (Drag.dragTo model.mouse.curMousePos model.drag), Maybe.Nothing)
        else
          --Or draw line on canvas
          let
            lineToDraw = (Mouse.getLine model.mouse (Colours.toHex model.curColour) model.lineWidth)
            drawLineCmd = drawLine lineToDraw
            newMouse = Mouse.update (Mouse.UpdatePrevPositions lineToDraw.lineMid) model.mouse
          in
            ({ model | mouse = newMouse }, drawLineCmd, Maybe.Just lineToDraw)
      else
        (model, Cmd.none, Maybe.Nothing)

update : Msg -> Model -> Model
update msg model =
  case msg of
    CanvasMouseMoved event ->
      let
        newMouse = Mouse.update (Mouse.CanvasMouseMoved event) model.mouse
      in
        { model | mouse = newMouse, mouseDown = event.mouseDown }
    CanvasMouseDown mousePos ->
      { model | mouseDown = True, drag = Drag.dragStart model.drag mousePos }
    CanvasMouseUp ->
      { model | mouseDown = False, drag = Drag.dragStop model.drag }
    ColourSelected colour ->
      { model | curColour = colour }
    Zoom zoom ->
      let
        drawMode = model.selectedDrawMode && (zoom <= 500)
      in
        { model | zoom = zoom, drawMode = drawMode }
    ToggleDrawMode ->
      let
        selectedDrawMode = not model.selectedDrawMode
      in
        { model | drawMode = selectedDrawMode, selectedDrawMode = selectedDrawMode }
    LineWidthSelected width ->
      {model | lineWidth = width}


-- SUBSCRIPTIONS

subscriptions : Sub Msg
subscriptions =
  Sub.batch
    [ canvasMouseMoved CanvasMouseMoved
    , canvasMouseDown CanvasMouseDown
    , canvasMouseUp (\_ -> CanvasMouseUp)
    , canvasZoom Zoom
    ]

animationSubscription : Sub AnimationMsg
animationSubscription =
  AnimationFrame.diffs AnimationFrame

-- VIEW

