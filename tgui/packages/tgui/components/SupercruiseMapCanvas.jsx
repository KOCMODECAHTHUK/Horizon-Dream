import { Component } from 'react';

/**
 * # SupercruiseMapCanvas
 *
 * Renders orbital objects on a Canvas2D with full 3D projection.
 * Inspired by Homeworld-style camera and depth sorting.
 * Uses painter's algorithm for proper object occlusion.
 */
const FPS = 30;
const DEG2RAD = Math.PI / 180;

export class SupercruiseMapCanvas extends Component {
  constructor(props) {
    super(props);
    this.canvasRef = null;
    this.renderUpdate = null;
    this.dragging = false;
    this.lastDragPos = null;
    this.lastClickPos = null;
  }

  componentDidMount() {
    this.resizeCanvas();
    this.renderUpdate = setInterval(() => this.draw(), 1000 / FPS);
    this.resizeObserver = new ResizeObserver(() => { this.resizeCanvas(); this.draw(); });
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
    // Redraw on prop changes (handled by interval, but force on major changes)
    if (prevProps.update_index !== this.props.update_index) {
      this.draw();
    }
  }

  /**
   * Project a 3D world point to 2D screen coordinates.
   * Uses orbit camera: rotate around focus point, then perspective project.
   */
  projectPoint(worldX, worldY, worldZ) {
    const {
      cameraYaw = 45,
      cameraPitch = 30,
      cameraDistance = 600,
      focusX = 0,
      focusY = 0,
      focusZ = 0,
      zoomScale = 1,
    } = this.props;

    // Get canvas dimensions from the actual canvas element
    const canvas = this.canvasRef;
    const dpr = window.devicePixelRatio || 1;
    const canvasWidth = canvas ? canvas.width / dpr : 700;
    const canvasHeight = canvas ? canvas.height / dpr : 700;

    // Translate relative to focus point
    const rx = worldX - focusX;
    const ry = worldY - focusY;
    const rz = worldZ - focusZ;

    // Rotate around Z axis (yaw)
    const yawRad = cameraYaw * DEG2RAD;
    const cosY = Math.cos(yawRad);
    const sinY = Math.sin(yawRad);
    const x1 = rx * cosY - ry * sinY;
    const y1 = rx * sinY + ry * cosY;
    const z1 = rz;

    // Rotate around X axis (pitch)
    const pitchRad = cameraPitch * DEG2RAD;
    const cosP = Math.cos(pitchRad);
    const sinP = Math.sin(pitchRad);
    const x2 = x1;
    const y2 = y1 * cosP - z1 * sinP;
    const z2 = y1 * sinP + z1 * cosP;

    // Perspective projection
    const effectiveDist = cameraDistance / zoomScale;
    const perspectiveScale = effectiveDist / (effectiveDist + y2);
    const screenX = (x2 * perspectiveScale) + canvasWidth / 2;
    const screenY = -(z2 * perspectiveScale) + canvasHeight / 2; // Flip Z for screen coords

    return {
      x: screenX,
      y: screenY,
      depth: y2, // Depth for sorting (further = larger depth)
      scale: perspectiveScale,
    };
  }

  /**
   * Unproject a 2D screen point to 3D world coordinates on the Z=0 plane.
   */
  unprojectToGroundPlane(screenX, screenY) {
    const {
      cameraYaw = 45,
      cameraPitch = 30,
      cameraDistance = 600,
      focusX = 0,
      focusY = 0,
      focusZ = 0,
      zoomScale = 1,
    } = this.props;

    const canvas = this.canvasRef;
    const dpr = window.devicePixelRatio || 1;
    const canvasWidth = canvas ? canvas.width / dpr : 700;
    const canvasHeight = canvas ? canvas.height / dpr : 700;

    const effectiveDist = cameraDistance / zoomScale;

    // Convert screen to projected coords
    const projX = screenX - canvasWidth / 2;
    const projZ = -(screenY - canvasHeight / 2);

    // Reverse perspective: we need to find world coords on Z=0 plane
    // This is approximate - assumes we're clicking on the focus Z plane
    const pitchRad = cameraPitch * DEG2RAD;
    const cosP = Math.cos(pitchRad);
    const sinP = Math.sin(pitchRad);

    // On the Z=0 plane, z1 = 0, so:
    // y2 = y1 * cosP (since z1=0)
    // z2 = y1 * sinP
    // perspectiveScale = effectiveDist / (effectiveDist + y1 * cosP)
    // projX = x2 * perspectiveScale
    // projZ = y1 * sinP * perspectiveScale

    // Solve for y1 from projZ:
    // projZ = y1 * sinP * (effectiveDist / (effectiveDist + y1 * cosP))
    // This is complex, so let's use a simpler approach:
    // Assume the click is on the plane at focusZ

    // Approximate: use inverse of projection at depth=0
    const approxScale = 1; // Will be refined
    const x2 = projX;
    const y1_approx = effectiveDist * 0; // Start guess

    // Better approach: iterate to find the ground plane intersection
    // For now, use a simple approximation assuming moderate pitch angles
    const yawRad = cameraYaw * DEG2RAD;
    const cosY = Math.cos(yawRad);
    const sinY = Math.sin(yawRad);

    // Simple inverse: assume perspective scale ≈ 1 (works for distant camera)
    const worldX_approx = x2 * cosY + focusX;
    const worldY_approx = -x2 * sinY + focusY;

    // Refine by computing the actual perspective scale at this depth
    // ... this is getting complex, let's use a ray-plane intersection approach

    // Ray from camera through screen point
    const camDist = effectiveDist;
    // Camera position in rotated space: (0, -camDist, 0) before pitch rotation
    // After pitch: (0, -camDist*cosP, camDist*sinP)
    // After yaw: (camDist*sinY*0 + ...) -- actually camera is at origin looking down -Y

    // Simplified: project back using average scale factor
    const avgScale = effectiveDist / (effectiveDist + 0);

    // Reverse the projection for the ground plane (z1 = 0):
    // screenX = x2 * scale + cx
    // screenY = -(y1 * sinP * scale) + cy
    // x2 = x1 (no yaw change on x)
    // y1 * cosP = depth component

    // For ground plane clicks, we need to find x1, y1 such that:
    // x1 = (projX) / avgScale
    // y1 = -(projZ) / (sinP * avgScale) ... approximately

    // Let's just do it properly with ray casting
    // Camera pos in view space: (0, -camDist, 0)
    // Screen point in view space: (projX/scale, 0, projZ/scale) at depth=0

    // For now, use the simpler unproject that works for moderate pitch:
    const groundX1 = projX / avgScale;
    const groundY1 = -projZ / (sinP * avgScale + cosP * 0.01);

    // Rotate back by yaw
    const worldX = groundX1 * cosY + groundY1 * sinY + focusX;
    const worldY = -groundX1 * sinY + groundY1 * cosY + focusY;

    return { worldX, worldY, worldZ: focusZ };
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
      update_index = 0,
      shuttleAngle = 0,
      shuttlePitch = 0,
      shuttleThrust = 0,
      ourObject = null,
      targetX = null,
      targetY = null,
      targetZ = null,
      isDocked = false,
      autopilotEnabled = false,
      cameraYaw = 45,
      cameraPitch = 30,
      onMapClick = null,
      onRotate = null,
    } = this.props;

    // Clear canvas
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = '#0a0a1a';
    ctx.fillRect(0, 0, canvasWidth, canvasHeight);

    // Draw grid on Z=0 plane
    this.drawGrid(ctx, canvasWidth, canvasHeight);

    // Calculate interpolation elapsed time
    const now = Date.now();

    // Collect all drawable items with their projected positions
    const drawItems = [];

    // Draw objects
    for (const obj of map_objects) {
      // Interpolate position
      const isStatic = obj.render_mode === 'station' || obj.render_mode === 'planet';
      // BYOND arrays serialize as JSON arrays (0-indexed in JS)
      const posX = obj.position_x ?? 0;
      const posY = obj.position_y ?? 0;
      const posZ = obj.position_z ?? 0;
      const velX = isStatic ? 0 : (obj.velocity_x ?? 0);
      const velY = isStatic ? 0 : (obj.velocity_y ?? 0);
      const velZ = isStatic ? 0 : (obj.velocity_z ?? 0);

      // Simple extrapolation for smooth movement
      const elapsed = 0.3; // approximate 300ms since last update
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
        type: 'object',
        obj,
        worldX, worldY, worldZ,
        projected,
        ground,
        color,
        isOurShuttle,
        depth: projected.depth,
      });
    }

    // Sort by depth (painter's algorithm - draw far objects first)
    drawItems.sort((a, b) => b.depth - a.depth);

    // Draw altitude reference lines first (behind objects)
    for (const item of drawItems) {
      if (item.type !== 'object') continue;
      const { ground, projected, worldZ, color, isOurShuttle, obj } = item;
      const altitude = worldZ;
      if (Math.abs(altitude) > 0.5 || isOurShuttle) {
        // Vertical line from ground to object
        ctx.strokeStyle = '#ff88ff';
        ctx.globalAlpha = 0.3;
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(ground.x, ground.y);
        ctx.lineTo(projected.x, projected.y);
        ctx.stroke();

        // Ground shadow circle
        ctx.globalAlpha = 0.15;
        ctx.fillStyle = '#ff88ff';
        ctx.beginPath();
        ctx.arc(ground.x, ground.y, 3, 0, Math.PI * 2);
        ctx.fill();
        ctx.globalAlpha = 1;
      }
    }

    // Draw all sorted items
    for (const item of drawItems) {
      if (item.type !== 'object') continue;
      const { obj, worldX, worldY, worldZ, projected, ground, color, isOurShuttle } = item;
      const altitude = worldZ;
      const r = Math.max(2, (obj.radius || 5) * projected.scale);

      const isStation = obj.render_mode === 'station';
      const isPlanet = obj.render_mode === 'planet';

      // Draw position history trail for our shuttle
      if (isOurShuttle && obj.position_history && obj.position_history.length > 1) {
        ctx.strokeStyle = '#a4eea4';
        ctx.lineWidth = 1.5;
        ctx.globalAlpha = 0.4;
        ctx.beginPath();
        const history = obj.position_history;
        for (let i = 0; i < history.length; i++) {
          const pos = history[i];
          // BYOND sends 1-indexed arrays, JSON serializes as 0-indexed
          const hx = Array.isArray(pos) ? (pos[0] || pos[1] || 0) : (pos.x || 0);
          const hy = Array.isArray(pos) ? (pos[1] || pos.y || 0) : (pos.y || 0);
          const hz = Array.isArray(pos) ? (pos[2] || pos[3] || 0) : (pos.z || 0);
          const hProj = this.projectPoint(hx, hy, hz);
          if (i === 0) ctx.moveTo(hProj.x, hProj.y);
          else ctx.lineTo(hProj.x, hProj.y);
        }
        ctx.stroke();
        ctx.globalAlpha = 1;
      }

      // Draw the object itself
      if (isStation) {
        // Station: diamond shape
        const dockingRange = (obj.docking_range || 20) * projected.scale;

        // Docking range circle (on ground plane)
        ctx.strokeStyle = '#88aaff';
        ctx.lineWidth = 1;
        ctx.globalAlpha = 0.3;
        ctx.setLineDash([5, 5]);
        ctx.beginPath();
        ctx.arc(ground.x, ground.y, dockingRange, 0, Math.PI * 2);
        ctx.stroke();
        ctx.setLineDash([]);
        ctx.globalAlpha = 1;

        // Station square
        const halfR = r * 0.7;
        ctx.fillStyle = color;
        ctx.strokeStyle = '#88aaff';
        ctx.lineWidth = 2;
        ctx.fillRect(projected.x - halfR, projected.y - halfR, halfR * 2, halfR * 2);
        ctx.strokeRect(projected.x - halfR, projected.y - halfR, halfR * 2, halfR * 2);
      } else if (isPlanet) {
        // Planet: filled circle with glow
        ctx.globalAlpha = 0.15;
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.arc(ground.x, ground.y, r + 3, 0, Math.PI * 2);
        ctx.fill();
        ctx.globalAlpha = 1;

        ctx.fillStyle = color;
        ctx.strokeStyle = color;
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.arc(projected.x, projected.y, r, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
      } else {
        // Shuttle or other object
        if (!(isDocked && isOurShuttle)) {
          // Shadow on ground
          ctx.globalAlpha = 0.25;
          ctx.fillStyle = color;
          ctx.beginPath();
          ctx.arc(ground.x, ground.y, r * 0.6, 0, Math.PI * 2);
          ctx.fill();
          ctx.globalAlpha = 1;

          // Object dot
          ctx.fillStyle = color;
          ctx.beginPath();
          ctx.arc(projected.x, projected.y, r, 0, Math.PI * 2);
          ctx.fill();
        }
      }

      // Draw velocity vector (cyan) for our shuttle
      if (isOurShuttle) {
        const velX2 = obj.velocity_x ?? 0;
        const velY2 = obj.velocity_y ?? 0;
        const velZ2 = obj.velocity_z ?? 0;
        const velMag = Math.sqrt(velX2 * velX2 + velY2 * velY2 + velZ2 * velZ2);

        if (velMag > 0.5) {
          const velScale = 3;
          const velEnd = this.projectPoint(
            worldX + velX2 * velScale,
            worldY + velY2 * velScale,
            worldZ + velZ2 * velScale
          );
          ctx.strokeStyle = '#00ffff';
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.moveTo(projected.x, projected.y);
          ctx.lineTo(velEnd.x, velEnd.y);
          ctx.stroke();

          // Arrow head
          this.drawArrowHead(ctx, projected.x, projected.y, velEnd.x, velEnd.y, '#00ffff');
        }

        // Draw thrust vector (yellow)
        if (shuttleThrust > 0) {
          // thrust_vector is a BYOND list serialized as JSON array (0-indexed in JS)
          const tv = obj.thrust_vector;
          const tx = Array.isArray(tv) ? tv[0] : 0;
          const ty = Array.isArray(tv) ? tv[1] : 0;
          const tz = Array.isArray(tv) ? tv[2] : 0;
          const thrustMag = Math.sqrt(tx * tx + ty * ty + tz * tz);
          if (thrustMag > 0.001) {
            const thrustScale = 25;
            const thrustEnd = this.projectPoint(
              worldX + tx * thrustScale,
              worldY + ty * thrustScale,
              worldZ + tz * thrustScale
            );
            ctx.strokeStyle = '#ffff00';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.moveTo(projected.x, projected.y);
            ctx.lineTo(thrustEnd.x, thrustEnd.y);
            ctx.stroke();

            this.drawArrowHead(ctx, projected.x, projected.y, thrustEnd.x, thrustEnd.y, '#ffff00');
          }
        }
      }

      // Draw altitude label
      if (Math.abs(altitude) > 0.5 || isOurShuttle) {
        const altLabel = `Z:${altitude >= 0 ? '+' : ''}${altitude.toFixed(0)}`;
        ctx.fillStyle = '#ff88ff';
        ctx.font = `${Math.min(10 * projected.scale, 11)}px monospace`;
        ctx.textAlign = isOurShuttle ? 'right' : 'left';
        ctx.globalAlpha = 0.85;
        const labelOffset = isOurShuttle ? -(r + 8) : (r + 4);
        ctx.fillText(altLabel, projected.x + labelOffset, projected.y + 3);
        ctx.globalAlpha = 1;
      }

      // Draw name label
      if (!(isDocked && isOurShuttle)) {
        ctx.fillStyle = color;
        ctx.font = `${Math.min(12 * projected.scale, 13)}px sans-serif`;
        ctx.textAlign = 'left';
        ctx.fillText(obj.name || 'Unknown', projected.x + r + 4, projected.y + 4);
      }
    }

    // Draw target position marker
    if (autopilotEnabled && targetX !== null && targetY !== null) {
      const targetProj = this.projectPoint(targetX, targetY, targetZ || 0);
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

      // Crosshair
      ctx.beginPath();
      ctx.moveTo(targetProj.x - 15, targetProj.y);
      ctx.lineTo(targetProj.x + 15, targetProj.y);
      ctx.moveTo(targetProj.x, targetProj.y - 15);
      ctx.lineTo(targetProj.x, targetProj.y + 15);
      ctx.stroke();
    }

    // Draw altitude legend
    this.drawAltitudeLegend(ctx, canvasWidth, canvasHeight);
  }

  drawArrowHead(ctx, fromX, fromY, toX, toY, color) {
    const angle = Math.atan2(toY - fromY, toX - fromX);
    const headLen = 8;
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(toX, toY);
    ctx.lineTo(toX - headLen * Math.cos(angle - 0.4), toY - headLen * Math.sin(angle - 0.4));
    ctx.lineTo(toX - headLen * Math.cos(angle + 0.4), toY - headLen * Math.sin(angle + 0.4));
    ctx.closePath();
    ctx.fill();
  }

  drawGrid(ctx, canvasWidth, canvasHeight) {
    const gridSpacing = 50;
    const gridRange = 300;

    ctx.strokeStyle = '#303050';
    ctx.lineWidth = 0.5;
    ctx.globalAlpha = 0.4;

    // Draw grid lines on Z=0 plane
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

  drawAltitudeLegend(ctx, canvasWidth, canvasHeight) {
    const x = canvasWidth - 130;
    const y = 10;

    ctx.fillStyle = 'rgba(10, 10, 26, 0.85)';
    ctx.fillRect(x, y, 120, 85);
    ctx.strokeStyle = '#444';
    ctx.lineWidth = 1;
    ctx.strokeRect(x, y, 120, 85);

    ctx.fillStyle = '#ffffff';
    ctx.font = '11px sans-serif';
    ctx.textAlign = 'left';
    ctx.fillText('Altitude', x + 8, y + 16);

    ctx.strokeStyle = '#ff88ff';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x + 15, y + 30);
    ctx.lineTo(x + 15, y + 60);
    ctx.stroke();

    ctx.fillStyle = '#ff88ff';
    ctx.beginPath();
    ctx.arc(x + 15, y + 30, 3, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(x + 15, y + 60, 3, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#ffffff';
    ctx.font = '10px sans-serif';
    ctx.fillText('+ above plane', x + 24, y + 34);
    ctx.fillText('− below plane', x + 24, y + 64);

    ctx.fillStyle = '#888';
    ctx.font = '9px sans-serif';
    ctx.fillText('Z height shown on all objects', x + 4, y + 80);
  }

  handleMouseDown = (e) => {
    if (e.button === 0) {
      e.preventDefault();
      const rect = this.canvasRef.getBoundingClientRect();
      this.dragging = true;
      this.lastDragPos = { x: e.clientX, y: e.clientY };
      this.lastClickPos = { x: e.clientX, y: e.clientY };
    }
  };

  handleMouseMove = (e) => {
    if (!this.dragging || !this.lastDragPos || !this.props.onRotate) return;
    const dx = e.clientX - this.lastDragPos.x;
    const dy = e.clientY - this.lastDragPos.y;
    this.lastDragPos = { x: e.clientX, y: e.clientY };
    this.props.onRotate(dx * 0.3, dy * 0.25);
  };

  handleMouseUp = () => {
    this.dragging = false;
    this.lastDragPos = null;
  };

  handleWheel = (e) => {
    e.preventDefault();
    if (this.props.onZoom) {
      const delta = e.deltaY > 0 ? 0.9 : 1.1;
      this.props.onZoom(delta);
    }
  };

  handleContextMenu = (e) => {
    e.preventDefault();
    if (!this.props.onMapClick) return;

    const rect = this.canvasRef.getBoundingClientRect();
    const clickX = e.clientX - rect.left;
    const clickY = e.clientY - rect.top;
    const { worldX, worldY, worldZ } = this.unprojectToGroundPlane(clickX, clickY);

    this.props.onMapClick(worldX, worldY, 'right', e.altKey);
  };

  handleDoubleClick = (e) => {
    if (!this.props.onMapClick) return;
    e.preventDefault();

    const rect = this.canvasRef.getBoundingClientRect();
    const clickX = e.clientX - rect.left;
    const clickY = e.clientY - rect.top;
    const { worldX, worldY, worldZ } = this.unprojectToGroundPlane(clickX, clickY);

    this.props.onMapClick(worldX, worldY, 'double', e.altKey);
  };

  render() {
    return (
      <canvas
        ref={(ref) => { this.canvasRef = ref; }}
        style={{
          position: 'absolute',
          width: '100%',
          height: '100%',
          cursor: 'grab',
        }}
        onMouseDown={this.handleMouseDown}
        onMouseMove={this.handleMouseMove}
        onMouseUp={this.handleMouseUp}
        onMouseLeave={this.handleMouseUp}
        onWheel={this.handleWheel}
        onContextMenu={this.handleContextMenu}
        onDoubleClick={this.handleDoubleClick}
      />
    );
  }
}
