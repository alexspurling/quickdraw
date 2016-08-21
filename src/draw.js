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

  console.log("Loading canvas", canvas);

  //Resize on window resize
  window.onresize = function() {
    app.ports.canvasResized.send({width:window.innerWidth, height:window.innerHeight});
  };
  window.onresize();

  canvas.addEventListener("mousemove", function (e) {
      var mousePos = {x: e.offsetX, y: e.offsetY};
      var mouseDown = e.buttons == 1;
      app.ports.canvasMouseMoved.send({mousePos: mousePos, mouseDown: mouseDown});
  }, false);

  var getMousePos = function(canvas, touchEvent) {
    var rect = canvas.getBoundingClientRect();
    var canvasX = parseInt(touchEvent.touches[0].clientX - rect.left);
    var canvasY = parseInt(touchEvent.touches[0].clientY - rect.top);
    return {x: canvasX, y: canvasY};
  };

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

/* Draw on the canvas */

app.ports.drawLine.subscribe(drawLine);

function drawLine(tileLine) {
  var i = tileLine.tile[0];
  var j = tileLine.tile[1];
  if(typeof tileMap[i] === 'undefined' || typeof tileMap[i][j] === 'undefined') {
      return;
  }
  //The position on the canvas on which to place the tiles
  var canvasX = i * (tileSize / scale) - (curX / scale);
  var canvasY = j * (tileSize / scale) - (curY / scale);
  var canvasTileSize = tileSize / scale;
  ctx.clearRect(canvasX, canvasY, (tileSize / scale), (tileSize / scale));
  drawTileLine(i, j, tileLine.line);
  copyTileToCanvas(i, j);
}

function drawTileLine(i, j, line) {
  var tile = tileMap[i][j];

  //Instead of doing simple straight lines between points A, B and C, we find the
  //mid-point between A and B and B and C and draw a quadratic
  //curve between these two points. This means we never reach as far as the current
  //mouse position but we get nice smooth curves between mouse positions
  //Algorithm was taken from: https://github.com/Leimi/drawingboard.js
  tile.strokeStyle = line.colour;
  tile.lineWidth = line.width;
  tile.beginPath();
  tile.moveTo(line.lastMid.x, line.lastMid.y);
  tile.quadraticCurveTo(line.lineFrom.x, line.lineFrom.y, line.lineMid.x, line.lineMid.y);
  tile.stroke();
  tile.closePath();
}

function copyTileToCanvas(i, j) {
  if (tileMap[i] && tileMap[i][j]) {
    var tile = tileMap[i][j];
    //The position on the canvas on which to place the tiles
    var canvasX = i * (tileSize / scale) - (curX / scale);
    var canvasY = j * (tileSize / scale) - (curY / scale);
    var canvasTileSize = tileSize / scale;
    ctx.drawImage(tile.canvas, canvasX, canvasY, canvasTileSize, canvasTileSize);
  }
}

/* Update the current view of the canvas */

app.ports.updateCanvas.subscribe(updateCanvas);

function updateCanvas(canvasViewAndTileDiff) {
  var canvasView = canvasViewAndTileDiff[0];
  var tileDiff = canvasViewAndTileDiff[1];
  createTiles(tileDiff.newTiles);
  removeTiles(tileDiff.oldTiles);
  zoom = canvasView.zoom;
  scale = canvasView.scale;
  curX = canvasView.curPos.x;
  curY = canvasView.curPos.y;
  if (canvas.width != canvasView.size.width) {
    canvas.width = canvasView.size.width;
  }
  if (canvas.height != canvasView.size.height) {
    canvas.height = canvasView.size.height;
  }
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

function createTiles(tilesToCreate) {
  tilesToCreate.map(function(tilePos) {
    var i = tilePos[0];
    var j = tilePos[1];
    var tileCol = tileMap[i];
    if (!tileCol) {
      tileMap[i] = tileCol = {};
    }
    if (!tileCol[j]) {
      tileCol[j] = newTile();
    }
  });
}

function removeTiles(tilesToRemove) {
  tilesToRemove.map(function(tilePos) {
    var i = tilePos[0];
    var j = tilePos[1];
    var tileCol = tileMap[i];
    if (!tileCol) {
      console.log("Uh, this tile never existed:", tilePos);
      return;
    }
    var tile = tileCol[j];
    if (!tile) {
      console.log("Uh, this tile doesn't exist:", tilePos);
      return;
    }
    tileCol[j] = null;
  });
}

function newTile() {
  var tile = document.createElement('canvas');
  tile.width = tileSize;
  tile.height = tileSize;
  var tileCtx = tile.getContext('2d');
  tileCtx.lineCap = 'round';
  tileCtx.lineJoin = 'round';
  tileCtx.lineWidth = 3;
  tileCtx.strokeRect(0,0,tileSize,tileSize);
  tileCtx.lineWidth = 10;
  return tileCtx;
}

function copyFromTileMap() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  visibleTiles(function(i, j) {
    copyTileToCanvas(i, j);
  });
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