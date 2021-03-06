port module Canvas.Ports exposing (..)

import Set exposing (Set)
import Canvas.Vector exposing (Position)

type alias MouseMovedEvent =
  { mousePos: Position
  , mouseDown: Bool
  }

type alias Line =
  { lastMid : Position
  , lineFrom : Position
  , lineMid : Position
  , colour : String
  , width : Int
  }

type alias WheelEvent =
  { delta : Int
  , mousePos : Position
  }

type alias CanvasView =
  { size : CanvasSize
  , zoom : Int
  , scale : Float
  , curPos : Position
  }

type alias CanvasSize =
  { width : Int
  , height : Int
  }

type alias Tile = (Int, Int)

type alias TileLine =
  { line : Line
  , tile : Tile
  }

type alias TileDiff =
  { newTiles : List Tile
  , oldTiles : List Tile
  }

port loadCanvas : () -> Cmd msg

port canvasMouseMoved : (MouseMovedEvent -> msg) -> Sub msg

port canvasMouseUp : ({} -> msg) -> Sub msg

port canvasMouseDown : (Position -> msg) -> Sub msg

port drawLine : (TileLine) -> Cmd msg

port wheel : (WheelEvent -> msg) -> Sub msg

port updateCanvas : (CanvasView, TileDiff) -> Cmd msg

port canvasResized : (CanvasSize -> msg) -> Sub msg

port testEvent : ({} -> msg) -> Sub msg