var app = Elm.Main.fullscreen();

var canvas;
var ctx;
var scale = 1;

//Store a map of maps of canvas buffers
var tileMap;
var tileSize = 400;
//Current x,y position on the world
var curX = 0;
var curY = 0;
//Current zoom
var zoom = 0;
var scale = 1;
var lastPinchScale = 1;
var gridPosDragStart;

app.ports.loadCanvas.subscribe(function() {
  canvas = document.getElementById("mycanvas");
  ctx = canvas.getContext("2d");

  tileMap = {};

  resizeCanvas(canvas);
  //Resize on window resize
  window.onresize = function() {
    resizeCanvas(canvas);
  };
  console.log("Loading canvas", canvas);

  canvas.addEventListener("mousemove", function (e) {
      var mousePos = {x: e.offsetX, y: e.offsetY};
      var mouseDown = e.buttons == 1;
      app.ports.canvasMouseMoved.send({mousePos: mousePos, mouseDown: mouseDown});
  }, false);

  canvas.addEventListener("touchstart", function (e) {
      //Toggle the mouse down state to off because we want to
      //set this current position as the starting
      //point for our line when we start the 'move' event
      app.ports.canvasMouseMoved.send({mousePos: getMousePos(canvas, e), mouseDown: false});
  }, false);

  canvas.addEventListener("touchmove", function (e) {
      app.ports.canvasMouseMoved.send({mousePos: getMousePos(canvas, e), mouseDown: true});
  }, false);

  //Mobile gesture recognition
  var hammer = new Hammer(canvas);
  hammer.get('pinch').set({ enable: true });
  hammer.get('pan').set({ direction: Hammer.DIRECTION_ALL });
  hammer.on("pan", function(ev) {
    //TODO implement drag
  });
  var pinch = new Hammer.Pinch();
  hammer.add([pinch]);

  hammer.on("pinch pinchstart pinchend", function(ev) {

      //Get the point on the canvas around which we want to scale
      //This point should remain fixed as scale changes
      var scaledCanvasX = (canvas.width / 2) * scale + curX;
      var scaledCanvasY = (canvas.height / 2) * scale + curY;

      var hammerScale = 1 / ev.scale;
      scale = Math.max(0.5, Math.min(lastPinchScale * hammerScale, 8));
      zoom = Math.log2(scale) * 1000;

      //Adjust the current grid position so that the previous
      //point below the mouse stays in the same location
      curX = scaledCanvasX - ((canvas.width / 2) * scale);
      curY = scaledCanvasY - ((canvas.height / 2) * scale);

      if(ev.type == "pinchend"){
          lastPinchScale = scale;
          debug("Pinch end scale is " + scale);
      }

      createTiles();
      copyFromTileMap();
  });

  canvas.addEventListener("mousedown", function (e) {
      var mousePos = {x: e.offsetX, y: e.offsetY};
      gridPosDragStart = {x: curX, y: curY};
      app.ports.canvasMouseDown.send(mousePos);
  }, false);

  canvas.addEventListener("mouseup", function (e) {
      app.ports.canvasMouseUp.send({});
  }, false);

  canvas.addEventListener("wheel", function (e) {
      var delta = e.deltaY;
      //Firefox gives a delta value in number of lines rather than pixels
      //so unfortunately the scrolling is lower resolution and we must scale
      //it by 20 (px per line)
      if (e.deltaMode == 1) {
          delta *= 20;
      }
      var mousePos = {x: e.offsetX, y: e.offsetY};
      app.ports.wheel.send({delta:delta, mousePos:mousePos});
  }, false);

  document.addEventListener("keydown", function (e) {
      if (39 == e.keyCode) {
        pan(1,0);
      } else if (37 == e.keyCode) {
        pan(-1,0);
      } else if (38 == e.keyCode) {
        pan(0,-1);
      } else if (40 == e.keyCode) {
        pan(0,1);
      }
  }, false);
});

function resizeCanvas(canvas) {

  //Initialise new buffer canvases if necessary
  var canvasWidth = window.innerWidth;
  var canvasHeight = window.innerHeight;

  // resize & clear the original canvas and copy back in pixel data from the buffer //
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;

  createTiles();

  //Copy the tile map to the canvas
  copyFromTileMap();
}

function createTiles() {
  visibleTiles(function(i, j) {
    //If the tile doesn't exist yet, create it
    var tileCol = tileMap[i];
    if (!tileCol) {
      tileMap[i] = tileCol = {};
    }
    var tile = tileCol[j];
    if (!tile) {
      tileCol[j] = tile = newTile(i, j);
    }
  });
}

function newTile(i, j) {
  var tile = document.createElement('canvas');
  tile.width = tileSize;
  tile.height = tileSize;
  var tileCtx = tile.getContext('2d');
  tileCtx.lineCap = 'round';
  tileCtx.lineJoin = 'round';
  tileCtx.lineWidth = 3;
//  tileCtx.strokeRect(0,0,tileSize,tileSize);
  tileCtx.lineWidth = 10;
  return tileCtx;
}

function copyFromTileMap() {
  visibleTiles(function(i, j) {
    copyTileToCanvas(i, j);
  });
}

function copyTileToCanvas(i, j) {
  var tile = tileMap[i][j];
  //The position on the canvas on which to place the tiles
  var canvasX = i * (tileSize / scale) - (curX / scale);
  var canvasY = j * (tileSize / scale) - (curY / scale);
  var canvasTileSize = tileSize / scale;
  ctx.clearRect(canvasX, canvasY, (tileSize / scale), (tileSize / scale));
  ctx.drawImage(tile.canvas, canvasX, canvasY, canvasTileSize, canvasTileSize);
}

function getMousePos(canvas, touchEvent) {
  var rect = canvas.getBoundingClientRect();
  var canvasX = parseInt(touchEvent.touches[0].clientX - rect.left);
  var canvasY = parseInt(touchEvent.touches[0].clientY - rect.top);
  return {x: canvasX, y: canvasY};
}

app.ports.drawLine.subscribe(drawLine);

function drawLine(line) {

  //We don't actually need the coordinates of the most recent mouse
  //position other than to calculate the

  var tileCurveFrom = tileAt(line.lastMid);
  var tileCurveMid = tileAt(line.lineFrom);
  var tileCurveTo = tileAt(line.lineMid); //We draw the curve up to the midpoint of the current line

  //Loop through all the tiles that this line might pass through and draw on them
  //Note that the line might not actually intersect all of the tiles in which
  //case the line drawn will simply not be visible
  var minI = Math.min(tileCurveFrom.i, tileCurveMid.i, tileCurveTo.i);
  var maxI = Math.max(tileCurveFrom.i, tileCurveMid.i, tileCurveTo.i);
  var minJ = Math.min(tileCurveFrom.j, tileCurveMid.j, tileCurveTo.j);
  var maxJ = Math.max(tileCurveFrom.j, tileCurveMid.j, tileCurveTo.j);

  for (var i = minI; i <= maxI; i++) {
    for (var j = minJ; j <= maxJ; j++) {
       drawLineOnTile(i, j, line.lastMid, line.lineFrom, line.lineMid, line.colour, line.width);
       copyTileToCanvas(i, j);
    }
  }
}

function drawLineOnTile(i, j, lastMid, lineFrom, lineMid, colour, width) {

  var tile = tileMap[i][j];

  //Instead of doing simple straight lines between points A, B and C, we find the
  //mid-point between A and B and B and C and draw a quadratic
  //curve between these two points. This means we never reach as far as the current
  //mouse position but we get nice smooth curves between mouse positions
  //Algorithm was taken from: https://github.com/Leimi/drawingboard.js

  var curveFromTilePos = posOnTile(lastMid, i, j);
  //Note the curve mid is not the same as the line mid see above
  var curveMidTilePos = posOnTile(lineFrom, i, j);
  var curveToTilePos = posOnTile(lineMid, i, j);

  tile.strokeStyle = colour;
  tile.lineWidth = width;
  tile.beginPath();
  tile.moveTo(curveFromTilePos.x, curveFromTilePos.y);
  tile.quadraticCurveTo(curveMidTilePos.x, curveMidTilePos.y, curveToTilePos.x, curveToTilePos.y);
  tile.stroke();
  tile.closePath();
}

function vec(x, y) {
  return {x:x, y:y};
}

//Actually the magnitude of 3D cross product
function cross(v, w) {
  return v.x * w.y - v.y * w.x;
}

function minus(v, w) {
  return {x:(v.x - w.x), y:(v.y - w.y)};
}

function plus(v, w) {
  return {x:(v.x + w.x), y:(v.y + w.y)};
}

function multiply(v, s) {
  return {x:(v.x * s), y:(v.y * s)};
}

function div(v, d) {
  return {x:(v.x / d), y:(v.y / d)};
}

function tileAt(pos) {
  var scaledCanvasX = pos.x * scale + curX;
  var scaledCanvasY = pos.y * scale + curY;
  return {i: Math.floor(scaledCanvasX / tileSize), j: Math.floor(scaledCanvasY / tileSize)};
}

/* Get the position on a given tile
 for a given canvasX and canvasY
 */
function posOnTile(pos, i, j) {
  var scaledCanvasX = pos.x * scale + curX;
  var scaledCanvasY = pos.y * scale + curY;
  var tileX = scaledCanvasX - tileSize * i;
  var tileY = scaledCanvasY - tileSize * j;
  return {x:tileX, y:tileY};
}

function pan(x, y) {
  curX += 20 * x;
  curY += 20 * y;
  console.log("CurXY", curX, curY);
  createTiles();
  copyFromTileMap();
}

function visibleTiles(func) {
  var tileLeft = Math.floor(curX / tileSize);
  var tileTop = Math.floor(curY / tileSize);
  var numTilesI = scale * canvas.width / tileSize + 1;
  var numTilesJ = scale * canvas.height / tileSize + 1;
  for (var i = tileLeft; i < tileLeft + numTilesI; i++) {
    for (var j = tileTop; j < tileTop + numTilesJ; j++) {
      func(i, j);
    }
  }
}

app.ports.updateCanvas.subscribe(updateCanvas);

function updateCanvas(canvasState) {
  zoom = canvasState.zoom;
  scale = canvasState.scale;
  curX = canvasState.curPos.x;
  curY = canvasState.curPos.y;
  createTiles();
  copyFromTileMap();
}

function debug(debugStr) {
  var debugDiv = document.getElementById("debug2");
  if (!debugDiv) {
    debugDiv = document.createElement("div");
    debugDiv.id = "debug2";
    debugDiv.style.position = "absolute";
    debugDiv.style.bottom = "25px";
    document.body.appendChild(debugDiv);
  }
  debugDiv.innerHTML = debugStr;
  debugDiv.innerText = debugStr;
}