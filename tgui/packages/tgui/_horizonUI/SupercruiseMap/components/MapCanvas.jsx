import { Component } from 'react';
import { FPS, DEG2RAD, projectPoint as projectPointUtil, unprojectToGroundPlane as unprojectToGroundPlaneUtil } from './MapUtils';
import { renderMapObject, drawAltitudeLine } from './CanvasObjectRenderers';
import { drawHUD } from './CanvasHUD';
import { CanvasMouseController } from './CanvasMouseController';

/**
 * # SupercruiseMapCanvas
 *
 * Renders orbital objects on a Canvas2D with full 3D projection.
 * Inspired by Homeworld-style camera and depth sorting.
 * Uses painter's algorithm for proper object occlusion.
 */

export class SupercruiseMapCanvas extends Component {
  constructor(props) {
    super(props);
    this.canvasRef = null;
    this.renderUpdate = null;
    this.mouseController = new CanvasMouseController(
      () => this.canvasRef,
      () => this.props,
      this.projectPoint.bind(this),
      this.unprojectToGroundPlane.bind(this)
    );
  }

  componentDidMount() {
    this.resizeCanvas();
    this.renderUpdate = setInterval(() => this.draw(), 1000 / FPS);
    this.resizeObserver = new ResizeObserver(() => {
      this.resizeCanvas();
      this.draw();
    });
    if (this.canvasRef) this.resizeObserver.observe(this.canvasRef.parentElement);
  }

  componentWillUnmount() {
    if (this.renderUpdate) clearInterval(this.renderUpdate);
    if (this.resizeObserver) this.resizeObserver.disconnect();
  }

  resizeCanvas() {
    const canvas = this.canvasRef;
    if (!canvas) return;
    const parent = canvas.parentElement;
    if (!parent) return;
    const dpr = window.devicePixelRatio || 1;
    canvas.width = parent.clientWidth * dpr;
    canvas.height = parent.clientHeight * dpr;
    canvas.style.width = parent.clientWidth + 'px';
    canvas.style.height = parent.clientHeight + 'px';
  }

  componentDidUpdate(prevProps) {
    if (prevProps.update_index !== this.props.update_index) {
      this.draw();
    }
  }

  // Wrapper for external utility
  projectPoint(worldX, worldY, worldZ) {
    const canvas = this.canvasRef;
    const dpr = window.devicePixelRatio || 1;
    const canvasWidth = canvas ? canvas.width / dpr : 700;
    const canvasHeight = canvas ? canvas.height / dpr : 700;
    return projectPointUtil(worldX, worldY, worldZ, this.props, canvasWidth, canvasHeight);
  }

  // Wrapper for external utility
  unprojectToGroundPlane(screenX, screenY, targetZ = 0) {
    const canvas = this.canvasRef;
    const dpr = window.devicePixelRatio || 1;
    const canvasWidth = canvas ? canvas.width / dpr : 700;
    const canvasHeight = canvas ? canvas.height / dpr : 700;
    return unprojectToGroundPlaneUtil(screenX, screenY, targetZ, this.props, canvasWidth, canvasHeight);
  }

  draw() {
    const canvas = this.canvasRef;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const dpr = window.devicePixelRatio || 1;
    const canvasWidth = canvas.width / dpr;
    const canvasHeight = canvas.height / dpr;

    const {
      map_objects = [],
      shuttleAngle = 0,
      shuttlePitch = 0,
      shuttleThrust = 0,
      shuttleHeading = 0,
      shuttleHeadingPitch = 0,
      ourObject = null,
      targetX = null,
      targetY = null,
      targetZ = null,
      isDocked = false,
      autopilotEnabled = false,
      focusX = 0,
      focusY = 0,
      focusZ = 0,
    } = this.props;

    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = '#0a0a1a';
    ctx.fillRect(0, 0, canvasWidth, canvasHeight);

    this.drawGrid(ctx, canvasWidth, canvasHeight);

    for (const obj of map_objects) {
      if (obj.orbit_center_id && obj.orbit_radius) {
        this.drawOrbit(ctx, obj);
      }
    }

    const drawItems = [];

    for (const obj of map_objects) {
      const isStatic = obj.render_mode === 'station' || obj.render_mode === 'planet';
      const posX = obj.position_x ?? 0;
      const posY = obj.position_y ?? 0;
      const posZ = obj.position_z ?? 0;
      const velX = isStatic ? 0 : (obj.velocity_x ?? 0);
      const velY = isStatic ? 0 : (obj.velocity_y ?? 0);
      const velZ = isStatic ? 0 : (obj.velocity_z ?? 0);

      const elapsed = 0.3;
      const worldX = posX + velX * elapsed;
      const worldY = posY + velY * elapsed;
      const worldZ = posZ + velZ * elapsed;

      const projected = this.projectPoint(worldX, worldY, worldZ);
      const ground = this.projectPoint(worldX, worldY, 0);

      const color = obj.supercruise_color ||
        (obj.render_mode === 'shuttle' ? '#a4eea4' :
        obj.render_mode === 'station' ? '#4488ff' :
        obj.render_mode === 'planet' ? '#8B7355' : '#ffaa00');

      const isOurShuttle = ourObject && obj.id === ourObject.id;

      drawItems.push({
        type: 'object', obj, worldX, worldY, worldZ, projected, ground, color, isOurShuttle, depth: projected.depth,
      });
    }

    drawItems.sort((a, b) => b.depth - a.depth);

    for (const item of drawItems) {
      if (item.type !== 'object') continue;
      drawAltitudeLine(ctx, item);
      renderMapObject(ctx, item, this.props, this.projectPoint.bind(this));
    }

    // Draw target position marker (active autopilot)
    if (autopilotEnabled && targetX !== null && targetY !== null) {
      const targetZVal = targetZ || 0;
      const targetProj = this.projectPoint(targetX, targetY, targetZVal);
      const baseZ = focusZ;
      const baseProj = this.projectPoint(targetX, targetY, baseZ);
      const groundProj = this.projectPoint(targetX, targetY, 0);

      ctx.strokeStyle = '#ff88ff';
      ctx.globalAlpha = 0.15;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(groundProj.x, groundProj.y);
      ctx.lineTo(baseProj.x, baseProj.y);
      ctx.stroke();
      ctx.globalAlpha = 1;

      if (Math.abs(targetZVal - baseZ) > 0.5) {
        ctx.strokeStyle = '#ff00ff';
        ctx.lineWidth = 2;
        ctx.globalAlpha = 0.7;
        ctx.beginPath();
        ctx.moveTo(baseProj.x, baseProj.y);
        ctx.lineTo(targetProj.x, targetProj.y);
        ctx.stroke();
        ctx.globalAlpha = 1;
      }

      const spinAngle = (Date.now() / 20) % 360;
      const spinRad = spinAngle * DEG2RAD;
      ctx.strokeStyle = '#ff00ff';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(targetProj.x, targetProj.y, 8, 0, Math.PI * 2);
      ctx.stroke();
      ctx.setLineDash([4, 4]);
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(targetProj.x, targetProj.y, 12 + 3 * Math.sin(spinRad), 0, Math.PI * 2);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.beginPath();
      ctx.moveTo(targetProj.x - 15, targetProj.y);
      ctx.lineTo(targetProj.x + 15, targetProj.y);
      ctx.moveTo(targetProj.x, targetProj.y - 15);
      ctx.lineTo(targetProj.x, targetProj.y + 15);
      ctx.stroke();
    }

    // Draw pending target marker (needs confirmation)
    const { pendingTargetX, pendingTargetY, pendingTargetZ, hasPendingTarget } = this.props;
    if (hasPendingTarget && pendingTargetX != null && pendingTargetY != null) {
      const pendingZVal = pendingTargetZ || 0;
      const pendingProj = this.projectPoint(pendingTargetX, pendingTargetY, pendingZVal);
      const baseZ = focusZ;
      const baseProj = this.projectPoint(pendingTargetX, pendingTargetY, baseZ);
      const groundProj = this.projectPoint(pendingTargetX, pendingTargetY, 0);
      const pulse = Math.sin(Date.now() / 300) * 0.5 + 0.5;

      ctx.strokeStyle = '#ffcc00';
      ctx.globalAlpha = 0.15;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(groundProj.x, groundProj.y);
      ctx.lineTo(baseProj.x, baseProj.y);
      ctx.stroke();
      ctx.globalAlpha = 1;

      if (Math.abs(pendingZVal - baseZ) > 0.5) {
        ctx.strokeStyle = '#ffcc00';
        ctx.lineWidth = 2;
        ctx.globalAlpha = 0.7;
        ctx.beginPath();
        ctx.moveTo(baseProj.x, baseProj.y);
        ctx.lineTo(pendingProj.x, pendingProj.y);
        ctx.stroke();
        ctx.globalAlpha = 1;
      }

      ctx.strokeStyle = `rgba(255, 200, 0, ${0.5 + pulse * 0.5})`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(pendingProj.x, pendingProj.y, 8 + pulse * 4, 0, Math.PI * 2);
      ctx.stroke();
      ctx.fillStyle = '#ffcc00';
      ctx.font = 'bold 12px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('?', pendingProj.x, pendingProj.y - 16);
      ctx.setLineDash([3, 3]);
      ctx.strokeStyle = '#ffcc00';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(pendingProj.x - 15, pendingProj.y);
      ctx.lineTo(pendingProj.x + 15, pendingProj.y);
      ctx.moveTo(pendingProj.x, pendingProj.y - 15);
      ctx.lineTo(pendingProj.x, pendingProj.y + 15);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    if (this.mouseController.hoveredObjectId) {
      const hovItem = drawItems.find(i => i.obj && i.obj.id === this.mouseController.hoveredObjectId);
      if (hovItem) {
        const hr = Math.max(6, (hovItem.obj.radius || 5) * hovItem.projected.scale + 4);
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 2;
        ctx.globalAlpha = 0.8;
        ctx.beginPath();
        ctx.arc(hovItem.projected.x, hovItem.projected.y, hr, 0, Math.PI * 2);
        ctx.stroke();
        ctx.globalAlpha = 1;

        const tipX = hovItem.projected.x + hr + 8;
        const tipY = hovItem.projected.y - 20;
        const tipW = 160;
        const tipH = 48;
        ctx.fillStyle = 'rgba(0, 0, 0, 0.85)';
        ctx.fillRect(tipX, tipY, tipW, tipH);
        ctx.strokeStyle = '#666';
        ctx.lineWidth = 1;
        ctx.strokeRect(tipX, tipY, tipW, tipH);
        ctx.fillStyle = '#fff';
        ctx.font = '11px sans-serif';
        ctx.textAlign = 'left';
        ctx.fillText(hovItem.obj.name || 'Unknown', tipX + 4, tipY + 14);
        ctx.fillStyle = '#aaa';
        ctx.font = '10px monospace';
        ctx.fillText(`X:${hovItem.worldX.toFixed(0)} Y:${hovItem.worldY.toFixed(0)} Z:${hovItem.worldZ.toFixed(0)} `, tipX + 4, tipY + 28);
        ctx.fillText(`Radius:${hovItem.obj.radius || 5}`, tipX + 4, tipY + 40);
      }
    }

    drawHUD(ctx, this.props, canvasWidth, canvasHeight);

    // Draw Z-adjustment marker (Ctrl + RMB in progress)
    if (this.mouseController.adjustingZ && this.mouseController.localPendingX != null) {
      const pendingZVal = this.mouseController.localPendingZ || 0;
      const pendingProj = this.projectPoint(this.mouseController.localPendingX, this.mouseController.localPendingY, pendingZVal);
      const baseZ = focusZ;
      const baseProj = this.projectPoint(this.mouseController.localPendingX, this.mouseController.localPendingY, baseZ);
      const groundProj = this.projectPoint(this.mouseController.localPendingX, this.mouseController.localPendingY, 0);
      const pulse = Math.sin(Date.now() / 300) * 0.5 + 0.5;

      ctx.strokeStyle = '#ffcc00';
      ctx.globalAlpha = 0.15;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(groundProj.x, groundProj.y);
      ctx.lineTo(baseProj.x, baseProj.y);
      ctx.stroke();
      ctx.globalAlpha = 1;

      if (Math.abs(pendingZVal - baseZ) > 0.5) {
        ctx.strokeStyle = '#ffcc00';
        ctx.lineWidth = 2;
        ctx.globalAlpha = 0.7;
        ctx.beginPath();
        ctx.moveTo(baseProj.x, baseProj.y);
        ctx.lineTo(pendingProj.x, pendingProj.y);
        ctx.stroke();
        ctx.globalAlpha = 1;
      } else {
        ctx.strokeStyle = '#ffcc00';
        ctx.globalAlpha = 0.5;
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(groundProj.x, groundProj.y);
        ctx.lineTo(pendingProj.x, pendingProj.y);
        ctx.stroke();
        ctx.globalAlpha = 1;
      }

      ctx.strokeStyle = `rgba(255, 200, 0, ${0.5 + pulse * 0.5})`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(pendingProj.x, pendingProj.y, 8 + pulse * 4, 0, Math.PI * 2);
      ctx.stroke();
      ctx.fillStyle = '#ffcc00';
      ctx.font = 'bold 12px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(`Z: ${Math.round(pendingZVal)}`, pendingProj.x, pendingProj.y - 16);
      ctx.setLineDash([3, 3]);
      ctx.strokeStyle = '#ffcc00';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(pendingProj.x - 15, pendingProj.y);
      ctx.lineTo(pendingProj.x + 15, pendingProj.y);
      ctx.moveTo(pendingProj.x, pendingProj.y - 15);
      ctx.lineTo(pendingProj.x, pendingProj.y + 15);
      ctx.stroke();
      ctx.setLineDash([]);
    }
  }

  drawGrid(ctx, canvasWidth, canvasHeight) {
    const gridSpacing = 50;
    const gridRange = 300;
    ctx.strokeStyle = '#303050';
    ctx.lineWidth = 0.5;
    ctx.globalAlpha = 0.4;
    for (let i = -gridRange; i <= gridRange; i += gridSpacing) {
      const start = this.projectPoint(i, -gridRange, 0);
      const end = this.projectPoint(i, gridRange, 0);
      ctx.beginPath();
      ctx.moveTo(start.x, start.y);
      ctx.lineTo(end.x, end.y);
      ctx.stroke();

      const start2 = this.projectPoint(-gridRange, i, 0);
      const end2 = this.projectPoint(gridRange, i, 0);
      ctx.beginPath();
      ctx.moveTo(start2.x, start2.y);
      ctx.lineTo(end2.x, end2.y);
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }

  drawOrbit(ctx, mapObj) {
    if (!mapObj.orbit_center_id || !mapObj.orbit_radius) return;

    const { map_objects = [] } = this.props;
    const centerObj = map_objects.find(o => o.id === mapObj.orbit_center_id);
    if (!centerObj) return;

    const centerX = centerObj.position_x;
    const centerY = centerObj.position_y;
    const centerZ = centerObj.position_z || 0;

    ctx.beginPath();
    ctx.strokeStyle = 'rgba(150, 180, 255, 0.07)';
    ctx.lineWidth = 1;

    const incRad = (mapObj.orbit_inclination || 0) * (Math.PI / 180);
    const ascRad = (mapObj.orbit_ascension || 0) * (Math.PI / 180);

    for (let i = 0; i <= 36; i++) {
      const angle = (i * 10) * (Math.PI / 180);

      let base_x = mapObj.orbit_radius * Math.cos(angle);
      let base_y = mapObj.orbit_radius * Math.sin(angle);
      let base_z = 0;

      let inc_x = base_x;
      let inc_y = base_y * Math.cos(incRad) - base_z * Math.sin(incRad);
      let inc_z = base_y * Math.sin(incRad) + base_z * Math.cos(incRad);

      let final_x = inc_x * Math.cos(ascRad) - inc_y * Math.sin(ascRad);
      let final_y = inc_x * Math.sin(ascRad) + inc_y * Math.cos(ascRad);
      let final_z = inc_z;

      let worldX = centerX + final_x;
      let worldY = centerY + final_y;
      let worldZ = centerZ + final_z;

      const screenPos = this.projectPoint(worldX, worldY, worldZ);
      if (i === 0) {
        ctx.moveTo(screenPos.x, screenPos.y);
      } else {
        ctx.lineTo(screenPos.x, screenPos.y);
      }
    }
    ctx.stroke();
  }

  render() {
    return (
      <canvas
        ref={(ref) => { this.canvasRef = ref; }}
        style={{ position: 'absolute', width: '100%', height: '100%', cursor: 'grab' }}
        onMouseDown={this.mouseController.handleMouseDown}
        onMouseMove={this.mouseController.handleMouseMove}
        onMouseUp={this.mouseController.handleMouseUp}
        onMouseLeave={this.mouseController.handleMouseUp}
        onWheel={this.mouseController.handleWheel}
        onContextMenu={this.mouseController.handleContextMenu}
        onDoubleClick={this.mouseController.handleDoubleClick}
      />
    );
  }
}
