module Canvas.Canvas exposing (..)

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
  , lineToDraw : Maybe Line
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
  , lineToDraw = Maybe.Nothing
  , viewUpdated = False
  , mousePosDragStart = Position 0 0
  , gridPosDragStart = Position 0 0
  , drawMode = True
  , selectedDrawMode = True
  , lineWidth = 10
  }
  , loadCanvas () )

tileSize = 400

-- UPDATE

type Msg = CanvasMouseMoved MouseMovedEvent
  | CanvasMouseDown Position
  | CanvasMouseUp
  | Wheel WheelEvent
  | CanvasResized CanvasSize
  | ColourSelected Colour
  | ToggleDrawMode
  | LineWidthSelected Int

updateAnimationFrame : Model -> Model
updateAnimationFrame model =
  if model.mouseDown && model.drawMode then
    updateLineToDraw model
  else
    { model | lineToDraw = Maybe.Nothing }


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


updateLineToDraw : Model -> Model
updateLineToDraw model =
  --Calculate the line to draw based on last calculated state
  --Update the model with the calculated state for this frame
  --Send a command to draw it on the canvas
  --Pass the line up to the parent to send to other clients
  let
    lineToDraw = (Mouse.getLine model.mouse (Colours.toHex model.curColour) model.lineWidth)
    newMouse = Mouse.update (Mouse.UpdatePrevPositions lineToDraw.lineMid) model.mouse
  in
    { model | mouse = newMouse, lineToDraw = Maybe.Just lineToDraw }


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
    scaledCanvasPos = getScaledPos model.canvasView mousePos

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

getLineOnTile : CanvasView -> Line -> Tile -> LineOnTile
getLineOnTile canvasView line tile =
  let
    lastMid = getPosOnTile canvasView line.lastMid tile
    lineFrom = getPosOnTile canvasView line.lineFrom tile
    lineMid = getPosOnTile canvasView line.lineMid tile
  in
    LineOnTile (Line lastMid lineFrom lineMid line.colour line.width) tile

getPosOnTile : CanvasView -> Position -> Tile -> Position
getPosOnTile canvasView pos tile =
  let
    scaledPos = getScaledPos canvasView pos
    tilePos = Vector.multiply (Position tile.i tile.j) tileSize
  in
    Vector.minus scaledPos tilePos

--Returns a command batch representing lines to draw on tiles
--the batch might contain more than one line/tile to draw if
--the line crosses a tile boundary
getLineWithTiles : Line -> CanvasView -> List LineOnTile
getLineWithTiles lineToDraw canvasView =
  getTilesForLine lineToDraw canvasView
    |> List.map (getLineOnTile canvasView lineToDraw)


--Returns the set of tiles that a line might have crossed
getTilesForLine : Line -> CanvasView -> List Tile
getTilesForLine line canvasView =
  let
    tileCurveFrom = tileAt canvasView line.lastMid
    tileCurveMid = tileAt canvasView line.lineFrom
    tileCurveTo = tileAt canvasView line.lineMid --We only draw the curve up to the midpoint of the current line

    --Loop through all the tiles that this line might pass through and draw on them
    --Note that the line might not actually intersect all of the tiles in which
    --case the line drawn will simply not be visible
    minI = min3 tileCurveFrom.i tileCurveMid.i tileCurveTo.i
    maxI = max3 tileCurveFrom.i tileCurveMid.i tileCurveTo.i
    minJ = min3 tileCurveFrom.j tileCurveMid.j tileCurveTo.j
    maxJ = max3 tileCurveFrom.j tileCurveMid.j tileCurveTo.j

    rangeI = [minI..maxI]
    rangeJ = [minJ..maxJ]

    createTilesWithI js i =
      List.map (Tile i) js
  in
    List.concatMap (createTilesWithI rangeJ) rangeI

tileAt : CanvasView -> Position -> Tile
tileAt canvasView pos =
  let
    scaledCanvasPos = getScaledPos canvasView pos
    i = floor(toFloat (scaledCanvasPos.x) / toFloat(tileSize))
    j = floor(toFloat (scaledCanvasPos.y) / toFloat(tileSize))
  in
    Tile i j

getScaledPos : CanvasView -> Position -> Position
getScaledPos canvasView pos =
  Vector.plus (Vector.multiply pos canvasView.scale) canvasView.curPos

min3 : comparable -> comparable -> comparable -> comparable
min3 a b c =
  min a (min b c)

max3 : comparable -> comparable -> comparable -> comparable
max3 a b c =
  max a (max b c)

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

-- VIEW

