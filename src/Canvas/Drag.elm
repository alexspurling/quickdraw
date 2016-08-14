module Canvas.Drag exposing (..)

import Canvas.Ports exposing (..)
import Canvas.Vector exposing (..)

type alias Model =
  { dragging : Bool
  , dragStart : Position
  }

type Msg
  = DragStart MouseMovedEvent

-- INIT

init : Model
init =
  { dragging = False
  , dragStart = {x = 0, y = 0}
  }

-- UPDATE

dragStart : Model -> Position-> Model
dragStart model mousePos =
  {dragging = True, dragStart = mousePos}

dragStop : Model -> Model
dragStop model =
  {model | dragging = False}


dragTo : Position -> Model -> Position
dragTo curMousePos model =
  minus curMousePos model.dragStart