module Canvas.Canvas exposing (..)

import AnimationFrame
import Collage
import Element
import Time exposing (Time)

import Canvas.Ports exposing (..)
import Canvas.Mouse as Mouse
import Canvas.Colours as Colours exposing (Colour)
import Canvas.Vector as Vector exposing (Position)

-- MODEL

type alias Model =
  { mouse : Mouse.Model
  , mouseDown : Bool
  , curColour : Colour
  , canvasView : CanvasView
  , viewUpdated : Bool --A flag to tell whether or not to render the view for a given animation frame
  , mousePosDragStart : Position
  , gridPosDragStart : Position
  , drawMode : Bool
  , selectedDrawMode : Bool
  , lineWidth : Int
  }

init : (Model, Cmd Msg)
init =
  ( { mouse = Mouse.init
  , mouseDown = False
  , curColour = Colours.Black
  , canvasView = CanvasView (CanvasSize 800 600) 0 1 (Position 0 0)
  , viewUpdated = False
  , mousePosDragStart = Position 0 0
  , gridPosDragStart = Position 0 0
  , drawMode = True
  , selectedDrawMode = True
  , lineWidth = 10
  }
  , loadCanvas () )


-- UPDATE

type Msg = CanvasMouseMoved MouseMovedEvent
  | CanvasMouseDown Position
  | CanvasMouseUp
  | Wheel WheelEvent
  | CanvasResized CanvasSize
  | ColourSelected Colour
  | ToggleDrawMode
  | LineWidthSelected Int

type AnimationMsg =
  AnimationFrame Time

updateAnimationFrame : AnimationMsg -> Model -> (Model, Cmd Msg, Maybe Line)
updateAnimationFrame msg model =
  case msg of
    AnimationFrame delta ->
      if model.mouseDown && model.drawMode then
        updateLineDraw model
      else if model.viewUpdated then
        --The view was updated since the last frame so send a cmd to update it in JS
        let
          cmd = updateCanvas model.canvasView
        in
          ({ model | viewUpdated = False}, cmd, Maybe.Nothing)
      else
        (model, Cmd.none, Maybe.Nothing)


update : Msg -> Model -> Model
update msg model =
  case msg of
    CanvasMouseMoved event ->
      model |> updateMouse event |> updateDrag event.mousePos
    CanvasMouseDown mousePos ->
      { model | mouseDown = True, mousePosDragStart = mousePos, gridPosDragStart = model.canvasView.curPos }
    CanvasMouseUp ->
      { model | mouseDown = False }
    ColourSelected colour ->
      { model | curColour = colour }
    CanvasResized canvasSize ->
      updateCanvasSize model canvasSize
    Wheel wheelEvent ->
      updateZoom model wheelEvent.delta wheelEvent.mousePos
    ToggleDrawMode ->
      let
        selectedDrawMode = not model.selectedDrawMode
      in
        { model | drawMode = selectedDrawMode, selectedDrawMode = selectedDrawMode }
    LineWidthSelected width ->
      {model | lineWidth = width}


updateLineDraw : Model -> (Model, Cmd Msg, Maybe Line)
updateLineDraw model =
  --Calculate the line to draw based on last calculated state
  --Update the model with the calculated state for this frame
  --Send a command to draw it on the canvas
  --Pass the line up to the parent to send to other clients
  let
    lineToDraw = (Mouse.getLine model.mouse (Colours.toHex model.curColour) model.lineWidth)
    drawLineCmd = drawLine lineToDraw
    newMouse = Mouse.update (Mouse.UpdatePrevPositions lineToDraw.lineMid) model.mouse
  in
    ({ model | mouse = newMouse }, drawLineCmd, Maybe.Just lineToDraw)


updateMouse : MouseMovedEvent -> Model -> Model
updateMouse event model =
  let
    newMouse = Mouse.update (Mouse.CanvasMouseMoved event) model.mouse
  in
    { model | mouse = newMouse, mouseDown = event.mouseDown }


updateDrag : Position -> Model -> Model
updateDrag mousePos model =
  if (not model.drawMode) && model.mouseDown then
    let
      dragVec = Vector.minus mousePos model.mousePosDragStart
      scaledDragVec = Vector.multiply dragVec model.canvasView.scale
      curPos = Vector.minus model.gridPosDragStart scaledDragVec

      --This could be done by nested update but the current version of the Elm IntelliJ plugin doesn't like it
      curCanvasView = model.canvasView
      newCanvasView = { curCanvasView | curPos = curPos }
    in
      { model | canvasView = newCanvasView, viewUpdated = True }
  else
    model


updateZoom : Model -> Int -> Position -> Model
updateZoom model delta mousePos =
  let
    --Get the point on the canvas around which we want to scale
    --This point should remain fixed as scale changes
    scaledCanvasPos = Vector.plus (Vector.multiply mousePos model.canvasView.scale) model.canvasView.curPos

    zoom = clamp 0 3000 (model.canvasView.zoom + delta)
    scale = 2 ^ (zoom / 1000)

    --Adjust the current grid position so that the previous
    --point below the mouse stays in the same location
    curPos = Vector.minus scaledCanvasPos (Vector.multiply mousePos scale)

    drawMode = model.selectedDrawMode && (zoom <= 500)

    curCanvasView = model.canvasView
    newCanvasView = { curCanvasView | zoom = zoom, scale = scale, curPos = curPos }
  in
    { model | canvasView = newCanvasView, drawMode = drawMode, viewUpdated = True }

updateCanvasSize : Model -> CanvasSize -> Model
updateCanvasSize model canvasSize =
  let
    curCanvasView = model.canvasView
    newCanvasView = { curCanvasView | size = canvasSize }
  in
    { model | canvasView = newCanvasView, viewUpdated = True }

-- SUBSCRIPTIONS

subscriptions : Sub Msg
subscriptions =
  Sub.batch
    [ canvasMouseMoved CanvasMouseMoved
    , canvasMouseDown CanvasMouseDown
    , canvasMouseUp (\_ -> CanvasMouseUp)
    , wheel Wheel
    , canvasResized CanvasResized
    ]

animationSubscription : Sub AnimationMsg
animationSubscription =
  AnimationFrame.diffs AnimationFrame

-- VIEW

