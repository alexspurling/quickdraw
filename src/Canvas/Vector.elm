module Canvas.Vector exposing (..)

type alias Position =
  { x : Int
  , y : Int
  }

plus : Position -> Position -> Position
plus pos1 pos2 =
  {x = pos1.x + pos2.x, y = pos1.y + pos2.y}

minus : Position -> Position -> Position
minus pos1 pos2 =
  {x = pos1.x - pos2.x, y = pos1.y - pos2.y}

multiply : Position -> Float -> Position
multiply pos scale =
  {x = round ((toFloat pos.x) * scale), y = round ((toFloat pos.y) * scale)}

divide : Position -> Float -> Position
divide pos scale =
  {x = round ((toFloat pos.x) / scale), y = round ((toFloat pos.y) / scale)}

zero : Position -> Bool
zero pos =
  pos.x == 0 && pos.y == 0