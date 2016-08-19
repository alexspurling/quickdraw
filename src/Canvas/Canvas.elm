module Canvas.Canvas exposing (..)

import Collage
import Element
import Time exposing (Time)
import Set exposing (Set)

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
  , tileLines : Maybe (List TileLine)
  , visibleTiles : Set Tile
  , prevVisibleTiles : Set Tile
  , tileDiff : TileDiff
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
  , tileLines = Maybe.Nothing
  , visibleTiles = Set.empty
  , prevVisibleTiles = Set.empty
  , tileDiff = TileDiff Set.empty Set.empty
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
    { model | tileLines = Maybe.Nothing }
      |> updateTileDiff


update : Msg -> Model -> Model
update msg model =
  case msg of
    CanvasMouseMoved event ->
      model
        |> updateMouse event
        |> updateDrag event.mousePos
        |> updateVisibleTiles
    CanvasMouseDown mousePos ->
      { model | mouseDown = True, mousePosDragStart = mousePos, gridPosDragStart = model.canvasView.curPos }
    CanvasMouseUp ->
      { model | mouseDown = False }
    ColourSelected colour ->
      { model | curColour = colour }
    CanvasResized canvasSize ->
      model
        |> updateCanvasSize canvasSize
        |> updateVisibleTiles
    Wheel wheelEvent ->
      model
        |> updateZoom wheelEvent.delta wheelEvent.mousePos
        |> updateVisibleTiles
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
    tileLines = getTileLines lineToDraw model.canvasView
  in
    { model | mouse = newMouse, tileLines = Maybe.Just tileLines }


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


updateZoom : Int -> Position -> Model -> Model
updateZoom delta mousePos model =
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

updateCanvasSize : CanvasSize -> Model -> Model
updateCanvasSize canvasSize model =
  let
    curCanvasView = model.canvasView
    newCanvasView = { curCanvasView | size = canvasSize }
  in
    { model | canvasView = newCanvasView, viewUpdated = True }

updateVisibleTiles : Model -> Model
updateVisibleTiles model =
  let
    visibleTiles = getVisibleTiles model.canvasView
  in
    {model | visibleTiles = visibleTiles }

getVisibleTiles : CanvasView -> Set Tile
getVisibleTiles canvasView =
  let
    tileLeft = floor(toFloat (canvasView.curPos.x) / toFloat(tileSize))
    tileTop = floor(toFloat (canvasView.curPos.y) / toFloat(tileSize))

    numTilesI = floor (canvasView.scale * (toFloat canvasView.size.width) / tileSize + 1)
    numTilesJ = floor (canvasView.scale * (toFloat canvasView.size.height) / tileSize + 1)
  in
    getTileRange tileLeft (tileLeft+numTilesI) tileTop (tileTop+numTilesJ)
      |> Set.fromList

updateTileDiff : Model -> Model
updateTileDiff model =
  { model | tileDiff = getTileDiff model, prevVisibleTiles = model.visibleTiles }

getTileDiff : Model -> TileDiff
getTileDiff model =
  let
    newTiles = Set.diff model.visibleTiles model.prevVisibleTiles
    oldTiles = Set.diff model.prevVisibleTiles model.visibleTiles
  in
    TileDiff newTiles oldTiles

getTileLine : CanvasView -> Line -> Tile -> TileLine
getTileLine canvasView line tile =
  let
    lastMid = getPosOnTile canvasView line.lastMid tile
    lineFrom = getPosOnTile canvasView line.lineFrom tile
    lineMid = getPosOnTile canvasView line.lineMid tile
  in
    TileLine (Line lastMid lineFrom lineMid line.colour line.width) tile

getPosOnTile : CanvasView -> Position -> Tile -> Position
getPosOnTile canvasView pos (tileI, tileJ) =
  let
    scaledPos = getScaledPos canvasView pos
    tilePos = Vector.multiply (Position tileI tileJ) tileSize
  in
    Vector.minus scaledPos tilePos

--Returns a command batch representing lines to draw on tiles
--the batch might contain more than one line/tile to draw if
--the line crosses a tile boundary
getTileLines : Line -> CanvasView -> List TileLine
getTileLines lineToDraw canvasView =
  getTilesForLine lineToDraw canvasView
    |> List.map (getTileLine canvasView lineToDraw)


--Returns the set of tiles that a line might have crossed
getTilesForLine : Line -> CanvasView -> List Tile
getTilesForLine line canvasView =
  let
    (tileFromI, tileFromJ) = tileAt canvasView line.lastMid
    (tileMidI, tileMidJ) = tileAt canvasView line.lineFrom
    (tileToI, tileToJ) = tileAt canvasView line.lineMid --We only draw the curve up to the midpoint of the current line

    --Loop through all the tiles that this line might pass through and draw on them
    --Note that the line might not actually intersect all of the tiles in which
    --case the line drawn will simply not be visible
    minI = min3 tileFromI tileMidI tileToI
    maxI = max3 tileFromI tileMidI tileToI
    minJ = min3 tileFromJ tileMidJ tileToJ
    maxJ = max3 tileFromJ tileMidJ tileToJ
  in
    getTileRange minI maxI minJ maxJ

getTileRange : Int -> Int -> Int -> Int-> List Tile
getTileRange minI maxI minJ maxJ =
  let
    rangeI = [minI..maxI]
    rangeJ = [minJ..maxJ]

    createTilesWithI js i =
      List.map ((,) i) js
  in
    List.concatMap (createTilesWithI rangeJ) rangeI

tileAt : CanvasView -> Position -> Tile
tileAt canvasView pos =
  let
    scaledCanvasPos = getScaledPos canvasView pos
    i = floor(toFloat (scaledCanvasPos.x) / toFloat(tileSize))
    j = floor(toFloat (scaledCanvasPos.y) / toFloat(tileSize))
  in
    (i,j)

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

