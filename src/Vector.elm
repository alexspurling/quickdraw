module Vector exposing (..)

import Mouse exposing (Position)

plus : Position -> Position -> Position
plus pos1 pos2 =
  {x = pos1.x + pos2.x, y = pos1.y + pos2.y}

minus : Position -> Position -> Position
minus pos1 pos2 =
  {x = pos1.x - pos2.x, y = pos1.y - pos2.y}

multiply : Position -> Int -> Position
multiply pos scale =
  {x = pos.x * scale, y = pos.y * scale}

divide : Position -> Int -> Position
divide pos scale =
  {x = pos.x // scale, y = pos.y // scale}

zero : Position -> Bool
zero pos =
  pos.x == 0 && pos.y == 0