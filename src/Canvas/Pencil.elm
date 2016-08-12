module Canvas.Pencil exposing (..)

import Mouse exposing (Position)

import Canvas.Ports exposing (..)
import Canvas.Vector exposing (..)

type alias Model =
  { curMousePos : Position
  , prevMousePos : Position
  , prevMidPoint : Position
  }

type Msg
  = CanvasMouseMoved MouseMovedEvent
  | UpdatePrevPositions Position

-- INIT

init : Model
init =
  { curMousePos = {x = 0, y = 0}
  , prevMousePos = {x = 0, y = 0}
  , prevMidPoint = {x = 0, y = 0}
  }

-- UPDATE

update : Msg -> Model -> Model
update msg model =
  case msg of
    CanvasMouseMoved event ->
      --Don't change the prevMousePos or preMidPoint positions if we are currently drawing
      if event.mouseDown then
        {model | curMousePos = event.mousePos}
      else
        {model | curMousePos = event.mousePos, prevMousePos = event.mousePos, prevMidPoint = event.mousePos}
    UpdatePrevPositions midPoint ->
      {model | prevMousePos = model.curMousePos, prevMidPoint = midPoint}

getLine : Model -> String -> Line
getLine model colour =
  let
    curMid = calculateMidPosition model.prevMousePos model.curMousePos
  in
    Line model.prevMidPoint model.prevMousePos curMid colour

--Calculate the halfway point between two points
calculateMidPosition : Position -> Position -> Position
calculateMidPosition pos1 pos2 =
  divide (plus pos1 pos2) 2
