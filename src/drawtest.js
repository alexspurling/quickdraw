
function drawTest() {
  lastMid = {x: 0, y:600};
  lastLine = {x: 0, y:600};
  drawLine({from:{x: 0, y:600}, to:{x: 200, y:400}}, "#000000");
  drawLine({from:{x: 200, y:400}, to:{x: 400, y:400}}, "#000000");
  drawLine({from:{x: 400, y:400}, to:{x: 600, y:200}}, "#000000");
  drawLine({from:{x: 600, y:200}, to:{x: 1200, y:100}}, "#000000");
  drawLine({from:{x: 1200, y:100}, to:{x: 1400, y:400}}, "#000000");
  copyFromTileMap();
}