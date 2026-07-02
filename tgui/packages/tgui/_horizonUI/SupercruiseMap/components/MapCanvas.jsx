import { Component } from 'react';
import { FPS, DEG2RAD, projectPoint as projectPointUtil, unprojectToGroundPlane as unprojectToGroundPlaneUtil } from './MapUtils';
import { renderMapObject, drawAltitudeLine } from './CanvasObjectRenderers';
import { drawHUD } from './CanvasHUD';
import { CanvasMouseController } from './CanvasMouseController';
import { drawStarfield } from './CanvasBackground';

/*
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

  /**
   * Получение цвета объекта через switch вместо вложенных тернарников
   */
  getObjectColor(obj) {
    if (obj.supercruise_color) return obj.supercruise_color;

    switch (obj.render_mode) {
      case 'shuttle': return '#a4eea4';
      case 'station': return '#4488ff';
      case 'planet': return '#8B7355';
      default: return '#ffaa00';
    }
  }

  /**
   * Главная функция отрисовки, разбитая на логические блоки
   */
  draw() {
    const canvas = this.canvasRef;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const dpr = window.devicePixelRatio || 1;
    const canvasWidth = canvas.width / dpr;
    const canvasHeight = canvas.height / dpr;

    const { map_objects = [], focusZ = 0 } = this.props;

    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = '#0a0a1a';
    ctx.fillRect(0, 0, canvasWidth, canvasHeight);
    drawStarfield(ctx, this.props.cameraYaw || 45, this.props.cameraPitch || 30, canvasWidth, canvasHeight);

    this.drawGrid(ctx, canvasWidth, canvasHeight);
    this.drawOrbits(ctx, map_objects);

    const drawItems = this.prepareDrawItems(map_objects);

    for (const item of drawItems) {
      drawAltitudeLine(ctx, item);
      renderMapObject(ctx, item, this.props, this.projectPoint.bind(this));
    }

    this.drawTargetMarkers(ctx, focusZ);
    this.drawHoverTooltip(ctx, drawItems);

    drawHUD(ctx, this.props, canvasWidth, canvasHeight);

    this.drawZAdjustment(ctx, focusZ);
  }

  prepareDrawItems(map_objects) {
    const drawItems = [];
    const { ourObject = null } = this.props;

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

      drawItems.push({
        type: 'object',
        obj,
        worldX, worldY, worldZ,
        projected, ground,
        color: this.getObjectColor(obj),
        isOurShuttle: ourObject && obj.id === ourObject.id,
        depth: projected.depth,
      });
    }

    // Сортировка по глубине (Painter's algorithm)
    drawItems.sort((a, b) => b.depth - a.depth);
    return drawItems;
  }

  drawOrbits(ctx, map_objects) {
    for (const obj of map_objects) {
      if (obj.orbit_center_id && obj.orbit_radius) {
        this.drawOrbit(ctx, obj, map_objects);
      }
    }
  }

  /**
   * Единый метод для отрисовки активной и ожидающей целей
   */
  drawTargetMarkers(ctx, focusZ) {
    const { autopilotEnabled, targetX, targetY, targetZ, hasPendingTarget, pendingTargetX, pendingTargetY, pendingTargetZ } = this.props;

    // Active target
    if (autopilotEnabled && targetX != null && targetY != null) {
      const zVal = targetZ || 0;
      const proj = this.projectPoint(targetX, targetY, zVal);
      const baseProj = this.projectPoint(targetX, targetY, focusZ);
      const groundProj = this.projectPoint(targetX, targetY, 0);

      this.drawVerticalGuides(ctx, proj, baseProj, groundProj, zVal, focusZ, '#ff00ff', '#ff88ff');

      const spinRad = ((Date.now() / 20) % 360) * DEG2RAD;
      ctx.strokeStyle = '#ff00ff';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(proj.x, proj.y, 8, 0, Math.PI * 2);
      ctx.stroke();

      ctx.setLineDash([4, 4]);
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(proj.x, proj.y, 12 + 3 * Math.sin(spinRad), 0, Math.PI * 2);
      ctx.stroke();
      ctx.setLineDash([]);

      this.drawCrosshair(ctx, proj, 15, '#ff00ff');
    }

    // Pending target
    if (hasPendingTarget && pendingTargetX != null && pendingTargetY != null) {
      const zVal = pendingTargetZ || 0;
      const proj = this.projectPoint(pendingTargetX, pendingTargetY, zVal);
      const baseProj = this.projectPoint(pendingTargetX, pendingTargetY, focusZ);
      const groundProj = this.projectPoint(pendingTargetX, pendingTargetY, 0);
      const pulse = Math.sin(Date.now() / 300) * 0.5 + 0.5;

      this.drawVerticalGuides(ctx, proj, baseProj, groundProj, zVal, focusZ, '#ffcc00', '#ffcc00');

      ctx.strokeStyle = `rgba(255, 200, 0, ${0.5 + pulse * 0.5})`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(proj.x, proj.y, 8 + pulse * 4, 0, Math.PI * 2);
      ctx.stroke();

      ctx.fillStyle = '#ffcc00';
      ctx.font = 'bold 12px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('?', proj.x, proj.y - 16);

      ctx.setLineDash([3, 3]);
      this.drawCrosshair(ctx, proj, 15, '#ffcc00');
      ctx.setLineDash([]);
    }
  }

  drawHoverTooltip(ctx, drawItems) {
    if (!this.mouseController.hoveredObjectId) return;

    const hovItem = drawItems.find(i => i.obj && i.obj.id === this.mouseController.hoveredObjectId);
    if (!hovItem) return;

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
    ctx.fillText(`X:${hovItem.worldX.toFixed(0)} Y:${hovItem.worldY.toFixed(0)} Z:${hovItem.worldZ.toFixed(0)}`, tipX + 4, tipY + 28);
    ctx.fillText(`Radius:${hovItem.obj.radius || 5}`, tipX + 4, tipY + 40);
  }

  drawZAdjustment(ctx, focusZ) {
    if (!this.mouseController.adjustingZ || this.mouseController.localPendingX == null) return;

    const pendingZVal = this.mouseController.localPendingZ || 0;
    const proj = this.projectPoint(this.mouseController.localPendingX, this.mouseController.localPendingY, pendingZVal);
    const baseProj = this.projectPoint(this.mouseController.localPendingX, this.mouseController.localPendingY, focusZ);
    const groundProj = this.projectPoint(this.mouseController.localPendingX, this.mouseController.localPendingY, 0);
    const pulse = Math.sin(Date.now() / 300) * 0.5 + 0.5;

    this.drawVerticalGuides(ctx, proj, baseProj, groundProj, pendingZVal, focusZ, '#ffcc00', '#ffcc00');

    ctx.strokeStyle = `rgba(255, 200, 0, ${0.5 + pulse * 0.5})`;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(proj.x, proj.y, 8 + pulse * 4, 0, Math.PI * 2);
    ctx.stroke();

    ctx.fillStyle = '#ffcc00';
    ctx.font = 'bold 12px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(`Z: ${Math.round(pendingZVal)}`, proj.x, proj.y - 16);

    ctx.setLineDash([3, 3]);
    this.drawCrosshair(ctx, proj, 15, '#ffcc00');
    ctx.setLineDash([]);
  }

  // --- Хелперы для отрисовки ---

  drawVerticalGuides(ctx, targetProj, baseProj, groundProj, targetZVal, baseZ, baseColor, groundColor) {
    // Ground to base line
    ctx.strokeStyle = groundColor;
    ctx.globalAlpha = 0.15;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(groundProj.x, groundProj.y);
    ctx.lineTo(baseProj.x, baseProj.y);
    ctx.stroke();
    ctx.globalAlpha = 1;

    // Base to target line (if height difference is significant)
    if (Math.abs(targetZVal - baseZ) > 0.5) {
      ctx.strokeStyle = baseColor;
      ctx.lineWidth = 2;
      ctx.globalAlpha = 0.7;
      ctx.beginPath();
      ctx.moveTo(baseProj.x, baseProj.y);
      ctx.lineTo(targetProj.x, targetProj.y);
      ctx.stroke();
      ctx.globalAlpha = 1;
    }
  }

  drawCrosshair(ctx, proj, size, color) {
    ctx.strokeStyle = color;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(proj.x - size, proj.y);
    ctx.lineTo(proj.x + size, proj.y);
    ctx.moveTo(proj.x, proj.y - size);
    ctx.lineTo(proj.x, proj.y + size);
    ctx.stroke();
  }

  drawGrid(ctx, canvasWidth, canvasHeight) {
    const { focusX = 0, focusY = 0 } = this.props;
    const gridSpacing = 50;
    const fadeRange = 1000;
    const baseAlpha = 0.4;
    const drawRange = fadeRange + gridSpacing;
    const segments = 12;
    ctx.strokeStyle = '#303050';
    ctx.lineWidth = 0.5;
    const startX = Math.floor((focusX - drawRange) / gridSpacing) * gridSpacing;
    const endX = Math.floor((focusX + drawRange) / gridSpacing) * gridSpacing;
    const startY = Math.floor((focusY - drawRange) / gridSpacing) * gridSpacing;
    const endY = Math.floor((focusY + drawRange) / gridSpacing) * gridSpacing;
    for (let x = startX; x <= endX; x += gridSpacing) {
      for (let s = 0; s < segments; s++) {
        const y1 = startY + (s / segments) * (endY - startY);
        const y2 = startY + ((s + 1) / segments) * (endY - startY);
        const midY = (y1 + y2) / 2;
        const dist = Math.hypot(x - focusX, midY - focusY);
        const alpha = Math.max(0, 1 - dist / fadeRange) * baseAlpha;

        if (alpha > 0) {
          ctx.globalAlpha = alpha;
          const p1 = this.projectPoint(x, y1, 0);
          const p2 = this.projectPoint(x, y2, 0);
          ctx.beginPath();
          ctx.moveTo(p1.x, p1.y);
          ctx.lineTo(p2.x, p2.y);
          ctx.stroke();
        }
      }
    }
    for (let y = startY; y <= endY; y += gridSpacing) {
      for (let s = 0; s < segments; s++) {
        const x1 = startX + (s / segments) * (endX - startX);
        const x2 = startX + ((s + 1) / segments) * (endX - startX);
        const midX = (x1 + x2) / 2;
        const dist = Math.hypot(midX - focusX, y - focusY);
        const alpha = Math.max(0, 1 - dist / fadeRange) * baseAlpha;
        if (alpha > 0) {
          ctx.globalAlpha = alpha;
          const p1 = this.projectPoint(x1, y, 0);
          const p2 = this.projectPoint(x2, y, 0);
          ctx.beginPath();
          ctx.moveTo(p1.x, p1.y);
          ctx.lineTo(p2.x, p2.y);
          ctx.stroke();
        }
      }
    }
    ctx.globalAlpha = 1;
  }

  drawOrbit(ctx, mapObj, map_objects) {
    if (!mapObj.orbit_center_id || !mapObj.orbit_radius) return;

    const centerObj = map_objects.find(o => o.id === mapObj.orbit_center_id);
    if (!centerObj) return;

    const centerX = centerObj.position_x;
    const centerY = centerObj.position_y;
    const centerZ = centerObj.position_z || 0;

    ctx.beginPath();
    ctx.strokeStyle = 'rgba(150, 180, 255, 0.07)';
    ctx.lineWidth = 1;

    const incRad = (mapObj.orbit_inclination || 0) * DEG2RAD;
    const ascRad = (mapObj.orbit_ascension || 0) * DEG2RAD;
    const cosInc = Math.cos(incRad);
    const sinInc = Math.sin(incRad);
    const cosAsc = Math.cos(ascRad);
    const sinAsc = Math.sin(ascRad);

    for (let i = 0; i <= 36; i++) {
      const angle = (i * 10) * DEG2RAD;
      const base_x = mapObj.orbit_radius * Math.cos(angle);
      const base_y = mapObj.orbit_radius * Math.sin(angle);

      // Inclination rotation (X stays same, Y and Z rotate)
      const inc_y = base_y * cosInc;
      const inc_z = base_y * sinInc;

      // Ascension rotation (X and Y rotate, Z stays same)
      const final_x = base_x * cosAsc - inc_y * sinAsc;
      const final_y = base_x * sinAsc + inc_y * cosAsc;
      const final_z = inc_z;

      const screenPos = this.projectPoint(centerX + final_x, centerY + final_y, centerZ + final_z);

      if (i === 0) ctx.moveTo(screenPos.x, screenPos.y);
      else ctx.lineTo(screenPos.x, screenPos.y);
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
