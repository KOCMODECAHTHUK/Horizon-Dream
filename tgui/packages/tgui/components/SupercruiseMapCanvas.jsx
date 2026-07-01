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

/**
 * Helper functions for color manipulation
 */
function hexToRgb(hex) {
  if (!hex || typeof hex !== 'string') return { r: 128, g: 128, b: 128 };
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result ? {
    r: parseInt(result[1], 16),
    g: parseInt(result[2], 16),
    b: parseInt(result[3], 16)
  } : { r: 128, g: 128, b: 128 };
}

function rgbToHex(r, g, b) {
  return '#' + [r, g, b].map(x => {
    const hex = Math.round(Math.max(0, Math.min(255, x))).toString(16);
    return hex.length === 1 ? '0' + hex : hex;
  }).join('');
}

function lightenColor(hex, percent) {
  const rgb = hexToRgb(hex);
  return rgbToHex(
    rgb.r + (255 - rgb.r) * (percent / 100),
    rgb.g + (255 - rgb.g) * (percent / 100),
    rgb.b + (255 - rgb.b) * (percent / 100)
  );
}

function darkenColor(hex, percent) {
  const rgb = hexToRgb(hex);
  return rgbToHex(
    rgb.r * (1 - percent / 100),
    rgb.g * (1 - percent / 100),
    rgb.b * (1 - percent / 100)
  );
}

// Ship color for rendering
const SHIP_COLOR = '#a4eea4';

export class SupercruiseMapCanvas extends Component {
  constructor(props) {
    super(props);
    this.canvasRef = null;
    this.renderUpdate = null;
    this.dragging = false;
    this.lastDragPos = null;
    this.lastClickPos = null;
    this.hoveredObjectId = null;
    this.mouseScreenPos = null;

    // Добавленные переменные для Ctrl+ПКМ выбора высоты:
    this.adjustingZ = false;
    this.adjustZStartY = 0;
    this.adjustWorldX = 0;
    this.adjustWorldY = 0;
    this.adjustBaseZ = 0;
    this.adjustCurrentZ = 0;
    this.localPendingX = null;
    this.localPendingY = null;
    this.localPendingZ = null;
    this.normalRightClicked = false;
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
    if (prevProps.update_index !== this.props.update_index) {
      this.draw();
    }
  }

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

    const canvas = this.canvasRef;
    const dpr = window.devicePixelRatio || 1;
    const canvasWidth = canvas ? canvas.width / dpr : 700;
    const canvasHeight = canvas ? canvas.height / dpr : 700;

    const rx = worldX - focusX;
    const ry = worldY - focusY;
    const rz = worldZ - focusZ;

    const yawRad = cameraYaw * DEG2RAD;
    const cosY = Math.cos(yawRad);
    const sinY = Math.sin(yawRad);
    const x1 = rx * cosY - ry * sinY;
    const y1 = rx * sinY + ry * cosY;
    const z1 = rz;

    const pitchRad = cameraPitch * DEG2RAD;
    const cosP = Math.cos(pitchRad);
    const sinP = Math.sin(pitchRad);
    const x2 = x1;
    const y2 = y1 * cosP - z1 * sinP;
    const z2 = y1 * sinP + z1 * cosP;

    const effectiveDist = cameraDistance;
    const clampedDepth = Math.max(y2, -effectiveDist * 0.95);
    const perspectiveScale = effectiveDist / (effectiveDist + clampedDepth);
    const finalScale = perspectiveScale * zoomScale;
    const screenX = (x2 * finalScale) + canvasWidth / 2;
    const screenY = -(z2 * finalScale) + canvasHeight / 2;

    return { x: screenX, y: screenY, depth: y2, scale: finalScale };
  }

  unprojectToGroundPlane(screenX, screenY, targetZ = 0) {
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

    const effectiveDist = cameraDistance;
    const rz = targetZ - focusZ;

    const yawRad = cameraYaw * DEG2RAD;
    const pitchRad = cameraPitch * DEG2RAD;
    const cosY = Math.cos(yawRad);
    const sinY = Math.sin(yawRad);
    const cosP = Math.cos(pitchRad);
    const sinP = Math.sin(pitchRad);

    const projX = (screenX - canvasWidth / 2) / zoomScale;
    const projY = -(screenY - canvasHeight / 2) / zoomScale;

    const effDist = effectiveDist;
    const denom = projY * cosP - sinP * effDist;
    let y1;

    if (Math.abs(denom) < 0.001) {
      y1 = 0;
    } else {
      y1 = (rz * cosP * effDist + projY * rz * sinP - projY * effDist) / denom;
    }

    const y2 = y1 * cosP - rz * sinP;
    const s = effDist / (effDist + y2);
    const x1 = projX / s;

    const rx = x1 * cosY + y1 * sinY;
    const ry = -x1 * sinY + y1 * cosY;

    const worldX = rx + focusX;
    const worldY = ry + focusY;
    const worldZ = targetZ;

    return { worldX, worldY, worldZ };
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
      shuttleHeading = 0,
      shuttleHeadingPitch = 0,
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
      onObjectClick = null,
      shuttleVelX = 0,
      shuttleVelY = 0,
      shuttleVelZ = 0,
      shuttleAlt = 0,
      focusX = 0, // ВАЖНО: Извлекаем focusZ для линий высоты
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

    const now = Date.now();
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

    const labelCandidates = [];
    for (const item of drawItems) {
      if (item.type !== 'object') continue;
      const { ground, projected, worldZ, isOurShuttle } = item;
      const altitude = worldZ;
      if (Math.abs(altitude) > 0.5 || isOurShuttle) {
        ctx.strokeStyle = '#ff88ff';
        ctx.globalAlpha = 0.3;
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(ground.x, ground.y);
        ctx.lineTo(projected.x, projected.y);
        ctx.stroke();

        ctx.globalAlpha = 0.15;
        ctx.fillStyle = '#ff88ff';
        ctx.beginPath();
        ctx.arc(ground.x, ground.y, 3, 0, Math.PI * 2);
        ctx.fill();
        ctx.globalAlpha = 1;
      }
    }

    for (const item of drawItems) {
      if (item.type !== 'object') continue;
      const { obj, worldX, worldY, worldZ, projected, ground, color, isOurShuttle } = item;
      const altitude = worldZ;
      const r = Math.max(2, (obj.radius || 5) * projected.scale);
      const isStation = obj.render_mode === 'station';
      const isPlanet = obj.render_mode === 'planet';

      if (isOurShuttle && obj.position_history && obj.position_history.length > 1) {
        ctx.strokeStyle = '#a4eea4'; ctx.lineWidth = 1.5; ctx.globalAlpha = 0.4; ctx.beginPath();
        const history = obj.position_history;
        for (let i = 0; i < history.length; i++) {
          const pos = history[i];
          const hx = Array.isArray(pos) ? (pos[0] || pos[1] || 0) : (pos.x || 0);
          const hy = Array.isArray(pos) ? (pos[1] || pos.y || 0) : (pos.y || 0);
          const hz = Array.isArray(pos) ? (pos[2] || pos[3] || 0) : (pos.z || 0);
          const hProj = this.projectPoint(hx, hy, hz);
          if (i === 0) ctx.moveTo(hProj.x, hProj.y); else ctx.lineTo(hProj.x, hProj.y);
        }
        ctx.stroke(); ctx.globalAlpha = 1;
      }

      if (isStation) {
        const dockingRange = (obj.docking_range || 20) * projected.scale;
        ctx.strokeStyle = '#88aaff'; ctx.lineWidth = 1; ctx.globalAlpha = 0.3; ctx.setLineDash([5, 5]);
        ctx.beginPath(); ctx.arc(ground.x, ground.y, dockingRange, 0, Math.PI * 2); ctx.stroke();
        ctx.setLineDash([]); ctx.globalAlpha = 1;
        const halfR = r * 0.7;
        ctx.fillStyle = color; ctx.strokeStyle = '#88aaff'; ctx.lineWidth = 2;
        ctx.fillRect(projected.x - halfR, projected.y - halfR, halfR * 2, halfR * 2);
        ctx.strokeRect(projected.x - halfR, projected.y - halfR, halfR * 2, halfR * 2);
      } else if (isPlanet) {
        const planetRadius = Math.max(8, (obj.radius || 20) * projected.scale);
        ctx.globalAlpha = 0.2;
        const glowGradient = ctx.createRadialGradient(ground.x, ground.y, 0, ground.x, ground.y, planetRadius * 1.5);
        glowGradient.addColorStop(0, color); glowGradient.addColorStop(1, 'transparent');
        ctx.fillStyle = glowGradient; ctx.beginPath(); ctx.arc(ground.x, ground.y, planetRadius * 1.5, 0, Math.PI * 2); ctx.fill();
        ctx.globalAlpha = 1;
        const sphereGradient = ctx.createRadialGradient(projected.x - r * 0.3, projected.y - r * 0.3, r * 0.2, projected.x, projected.y, r);
        sphereGradient.addColorStop(0, lightenColor(color, 40)); sphereGradient.addColorStop(0.3, color); sphereGradient.addColorStop(1, darkenColor(color, 40));
        ctx.fillStyle = sphereGradient; ctx.beginPath(); ctx.arc(projected.x, projected.y, planetRadius, 0, Math.PI * 2); ctx.fill();
        ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.globalAlpha = 0.4;
        ctx.beginPath(); ctx.arc(projected.x, projected.y, planetRadius, 0, Math.PI * 2); ctx.stroke(); ctx.globalAlpha = 1;
      } else if (obj.render_mode === 'star' || obj.render_mode === 'sun') {
        const starRadius = Math.max(15, (obj.radius || 40) * projected.scale);
        ctx.save();
        ctx.globalCompositeOperation = 'lighter';
        ctx.globalAlpha = 0.15;
        const corona = ctx.createRadialGradient(projected.x, projected.y, 0, projected.x, projected.y, starRadius * 5);
        corona.addColorStop(0, '#ff8800');
        corona.addColorStop(0.4, 'rgba(255, 100, 0, 0.05)');
        corona.addColorStop(1, 'transparent');
        ctx.fillStyle = corona;
        ctx.beginPath(); ctx.arc(projected.x, projected.y, starRadius * 5, 0, Math.PI * 2); ctx.fill();
        ctx.globalAlpha = 0.4;
        const bloom = ctx.createRadialGradient(projected.x, projected.y, 0, projected.x, projected.y, starRadius * 2);
        bloom.addColorStop(0, '#ffffcc');
        bloom.addColorStop(0.5, 'rgba(255, 200, 50, 0.3)');
        bloom.addColorStop(1, 'transparent');
        ctx.fillStyle = bloom;
        ctx.beginPath(); ctx.arc(projected.x, projected.y, starRadius * 2, 0, Math.PI * 2); ctx.fill();
        ctx.globalAlpha = 0.9;
        const core = ctx.createRadialGradient(projected.x, projected.y, 0, projected.x, projected.y, starRadius * 1.2);
        core.addColorStop(0, '#ffffff');
        core.addColorStop(0.2, '#ffffee');
        core.addColorStop(0.6, '#ffcc00');
        core.addColorStop(1, 'transparent');
        ctx.fillStyle = core;
        ctx.beginPath(); ctx.arc(projected.x, projected.y, starRadius * 1.2, 0, Math.PI * 2); ctx.fill();
        ctx.restore();
      } else if (isOurShuttle) {
        const shuttleWidth = r * 2; const shuttleHeight = r * 1.5;
        const headingRad = ((shuttleHeading || 0) - 90) * DEG2RAD;
        ctx.save(); ctx.translate(projected.x, projected.y); ctx.rotate(headingRad);
        ctx.fillStyle = color || SHIP_COLOR; ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(0, -shuttleHeight); ctx.lineTo(-shuttleWidth * 0.5, shuttleHeight * 0.5); ctx.lineTo(shuttleWidth * 0.5, shuttleHeight * 0.5); ctx.closePath(); ctx.fill(); ctx.stroke();
        if (shuttleThrust > 0) {
          const flicker = 0.6 + 0.4 * Math.sin(Date.now() / 100); ctx.globalAlpha = flicker; ctx.fillStyle = '#ff6600';
          ctx.beginPath(); ctx.moveTo(-shuttleWidth * 0.3, shuttleHeight * 0.3); ctx.lineTo(-shuttleWidth * 0.5, shuttleHeight * 0.8 + shuttleThrust * 0.05); ctx.lineTo(shuttleWidth * 0.5, shuttleHeight * 0.8 + shuttleThrust * 0.05); ctx.lineTo(shuttleWidth * 0.3, shuttleHeight * 0.3); ctx.closePath(); ctx.fill(); ctx.globalAlpha = 1;
        }
        ctx.restore();
      } else {
        const objWidth = r * 1.5; const objHeight = r * 1.2; const objHeading = ((obj.heading || 0) - 90) * DEG2RAD;
        ctx.save(); ctx.translate(projected.x, projected.y); ctx.rotate(objHeading);
        ctx.fillStyle = color || '#888'; ctx.strokeStyle = color || '#888'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(0, -objHeight); ctx.lineTo(-objWidth * 0.5, objHeight * 0.5); ctx.lineTo(objWidth * 0.5, objHeight * 0.5); ctx.closePath(); ctx.fill(); ctx.stroke();
        ctx.restore();
      }

      if (isOurShuttle) {
        const velX2 = obj.velocity_x ?? 0; const velY2 = obj.velocity_y ?? 0; const velZ2 = obj.velocity_z ?? 0;
        const velMag = Math.sqrt(velX2 * velX2 + velY2 * velY2 + velZ2 * velZ2);
        if (velMag > 0.5) {
          const velScale = 3; const velEnd = this.projectPoint(worldX + velX2 * velScale, worldY + velY2 * velScale, worldZ + velZ2 * velScale);
          ctx.strokeStyle = '#00ffff'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(projected.x, projected.y); ctx.lineTo(velEnd.x, velEnd.y); ctx.stroke();
          this.drawArrowHead(ctx, projected.x, projected.y, velEnd.x, velEnd.y, '#00ffff');
        }
        const headingRad = shuttleHeading * DEG2RAD; const headingPitchRad = shuttleHeadingPitch * DEG2RAD; const headingScale = 20;
        const fwdX = Math.cos(headingRad) * Math.cos(headingPitchRad); const fwdY = Math.sin(headingRad) * Math.cos(headingPitchRad); const fwdZ = Math.sin(headingPitchRad);
        const headingEnd = this.projectPoint(worldX + fwdX * headingScale, worldY + fwdY * headingScale, worldZ + fwdZ * headingScale);
        ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 2; ctx.setLineDash([5, 3]); ctx.beginPath(); ctx.moveTo(projected.x, projected.y); ctx.lineTo(headingEnd.x, headingEnd.y); ctx.stroke(); ctx.setLineDash([]);
        const triAngle = Math.atan2(headingEnd.y - projected.y, headingEnd.x - projected.x);
        ctx.fillStyle = '#ffffff'; ctx.beginPath(); ctx.moveTo(headingEnd.x, headingEnd.y);
        ctx.lineTo(headingEnd.x - 8 * Math.cos(triAngle - 0.4), headingEnd.y - 8 * Math.sin(triAngle - 0.4));
        ctx.lineTo(headingEnd.x - 8 * Math.cos(triAngle + 0.4), headingEnd.y - 8 * Math.sin(triAngle + 0.4));
        ctx.closePath(); ctx.fill();
        if (shuttleThrust > 0) {
          const tv = obj.thrust_vector; const tx = Array.isArray(tv) ? tv[0] : 0; const ty = Array.isArray(tv) ? tv[1] : 0; const tz = Array.isArray(tv) ? tv[2] : 0;
          const thrustMag = Math.sqrt(tx * tx + ty * ty + tz * tz);
          if (thrustMag > 0.001) {
            const thrustScale = 25; const thrustEnd = this.projectPoint(worldX + tx * thrustScale, worldY + ty * thrustScale, worldZ + tz * thrustScale);
            ctx.strokeStyle = '#ffff00'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(projected.x, projected.y); ctx.lineTo(thrustEnd.x, thrustEnd.y); ctx.stroke();
            this.drawArrowHead(ctx, projected.x, projected.y, thrustEnd.x, thrustEnd.y, '#ffff00');
          }
        }
      }

      if (isOurShuttle) {
        const altLabel = `Z:${altitude >= 0 ? '+' : ''}${altitude.toFixed(0)}`;
        ctx.fillStyle = '#ff88ff'; ctx.font = `${Math.min(10 * projected.scale, 11)}px monospace`; ctx.textAlign = 'left'; ctx.globalAlpha = 0.85;
        const labelOffset = isOurShuttle ? -(r + 8) : (r + 4);
        ctx.fillText(altLabel, projected.x + labelOffset, projected.y + 3); ctx.globalAlpha = 1;
      }
      if (!(isDocked && isOurShuttle)) {
        ctx.fillStyle = color; ctx.font = `${Math.min(12 * projected.scale, 13)}px sans-serif`; ctx.textAlign = 'left';
        ctx.fillText(obj.name || 'Unknown', projected.x + r + 4, projected.y + 4);
      }
    }

    // Draw target position marker (active autopilot)
    if (autopilotEnabled && targetX !== null && targetY !== null) {
      const targetZVal = targetZ || 0;
      const targetProj = this.projectPoint(targetX, targetY, targetZVal);
      const baseZ = focusZ;
      const baseProj = this.projectPoint(targetX, targetY, baseZ);
      const groundProj = this.projectPoint(targetX, targetY, 0);

      ctx.strokeStyle = '#ff88ff'; ctx.globalAlpha = 0.15; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(groundProj.x, groundProj.y); ctx.lineTo(baseProj.x, baseProj.y); ctx.stroke(); ctx.globalAlpha = 1;

      if (Math.abs(targetZVal - baseZ) > 0.5) {
        ctx.strokeStyle = '#ff00ff'; ctx.lineWidth = 2; ctx.globalAlpha = 0.7;
        ctx.beginPath(); ctx.moveTo(baseProj.x, baseProj.y); ctx.lineTo(targetProj.x, targetProj.y); ctx.stroke(); ctx.globalAlpha = 1;
      }

      const spinAngle = (Date.now() / 20) % 360; const spinRad = spinAngle * DEG2RAD;
      ctx.strokeStyle = '#ff00ff'; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(targetProj.x, targetProj.y, 8, 0, Math.PI * 2); ctx.stroke();
      ctx.setLineDash([4, 4]); ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(targetProj.x, targetProj.y, 12 + 3 * Math.sin(spinRad), 0, Math.PI * 2); ctx.stroke(); ctx.setLineDash([]);
      ctx.beginPath(); ctx.moveTo(targetProj.x - 15, targetProj.y); ctx.lineTo(targetProj.x + 15, targetProj.y);
      ctx.moveTo(targetProj.x, targetProj.y - 15); ctx.lineTo(targetProj.x, targetProj.y + 15); ctx.stroke();
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

      // Линия от земли до текущей высоты (слабая)
      ctx.strokeStyle = '#ffcc00'; ctx.globalAlpha = 0.15; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(groundProj.x, groundProj.y); ctx.lineTo(baseProj.x, baseProj.y); ctx.stroke(); ctx.globalAlpha = 1;

      // Линия от текущей высоты до целевой Z (яркая)
      if (Math.abs(pendingZVal - baseZ) > 0.5) {
        ctx.strokeStyle = '#ffcc00'; ctx.lineWidth = 2; ctx.globalAlpha = 0.7;
        ctx.beginPath(); ctx.moveTo(baseProj.x, baseProj.y); ctx.lineTo(pendingProj.x, pendingProj.y); ctx.stroke(); ctx.globalAlpha = 1;
      }

      ctx.strokeStyle = `rgba(255, 200, 0, ${0.5 + pulse * 0.5})`; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(pendingProj.x, pendingProj.y, 8 + pulse * 4, 0, Math.PI * 2); ctx.stroke();
      ctx.fillStyle = '#ffcc00'; ctx.font = 'bold 12px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText('?', pendingProj.x, pendingProj.y - 16);
      ctx.setLineDash([3, 3]); ctx.strokeStyle = '#ffcc00'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(pendingProj.x - 15, pendingProj.y); ctx.lineTo(pendingProj.x + 15, pendingProj.y);
      ctx.moveTo(pendingProj.x, pendingProj.y - 15); ctx.lineTo(pendingProj.x, pendingProj.y + 15); ctx.stroke(); ctx.setLineDash([]);
    }

    if (this.hoveredObjectId) {
      const hovItem = drawItems.find(i => i.obj && i.obj.id === this.hoveredObjectId);
      if (hovItem) {
        const hr = Math.max(6, (hovItem.obj.radius || 5) * hovItem.projected.scale + 4);
        ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 2; ctx.globalAlpha = 0.8;
        ctx.beginPath(); ctx.arc(hovItem.projected.x, hovItem.projected.y, hr, 0, Math.PI * 2); ctx.stroke(); ctx.globalAlpha = 1;
        const tipX = hovItem.projected.x + hr + 8; const tipY = hovItem.projected.y - 20; const tipW = 160; const tipH = 48;
        ctx.fillStyle = 'rgba(0, 0, 0, 0.85)'; ctx.fillRect(tipX, tipY, tipW, tipH);
        ctx.strokeStyle = '#666'; ctx.lineWidth = 1; ctx.strokeRect(tipX, tipY, tipW, tipH);
        ctx.fillStyle = '#fff'; ctx.font = '11px sans-serif'; ctx.textAlign = 'left';
        ctx.fillText(hovItem.obj.name || 'Unknown', tipX + 4, tipY + 14);
        ctx.fillStyle = '#aaa'; ctx.font = '10px monospace';
        ctx.fillText(`X:${hovItem.worldX.toFixed(0)} Y:${hovItem.worldY.toFixed(0)} Z:${hovItem.worldZ.toFixed(0)} `, tipX + 4, tipY + 28);
        ctx.fillText(`Radius:${hovItem.obj.radius || 5}`, tipX + 4, tipY + 40);
      }
    }

    this.drawHUD(ctx, canvasWidth, canvasHeight);

    // Draw Z-adjustment marker (Ctrl + RMB in progress)
    if (this.adjustingZ && this.localPendingX != null) {
      const pendingZVal = this.localPendingZ || 0;
      const pendingProj = this.projectPoint(this.localPendingX, this.localPendingY, pendingZVal);
      const baseZ = focusZ;
      const baseProj = this.projectPoint(this.localPendingX, this.localPendingY, baseZ);
      const groundProj = this.projectPoint(this.localPendingX, this.localPendingY, 0);
      const pulse = Math.sin(Date.now() / 300) * 0.5 + 0.5;

      // Линия от земли до текущей высоты (слабая)
      ctx.strokeStyle = '#ffcc00'; ctx.globalAlpha = 0.15; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(groundProj.x, groundProj.y); ctx.lineTo(baseProj.x, baseProj.y); ctx.stroke(); ctx.globalAlpha = 1;

      // Линия от текущей высоты до целевой Z (яркая)
      if (Math.abs(pendingZVal - baseZ) > 0.5) {
        ctx.strokeStyle = '#ffcc00'; ctx.lineWidth = 2; ctx.globalAlpha = 0.7;
        ctx.beginPath(); ctx.moveTo(baseProj.x, baseProj.y); ctx.lineTo(pendingProj.x, pendingProj.y); ctx.stroke(); ctx.globalAlpha = 1;
      } else {
        // Если Z совпадает с текущей, рисуем просто от земли до курсора
        ctx.strokeStyle = '#ffcc00'; ctx.globalAlpha = 0.5; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(groundProj.x, groundProj.y); ctx.lineTo(pendingProj.x, pendingProj.y); ctx.stroke(); ctx.globalAlpha = 1;
      }

      ctx.strokeStyle = `rgba(255, 200, 0, ${0.5 + pulse * 0.5})`; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(pendingProj.x, pendingProj.y, 8 + pulse * 4, 0, Math.PI * 2); ctx.stroke();
      ctx.fillStyle = '#ffcc00'; ctx.font = 'bold 12px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText(`Z: ${Math.round(pendingZVal)}`, pendingProj.x, pendingProj.y - 16);
      ctx.setLineDash([3, 3]); ctx.strokeStyle = '#ffcc00'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(pendingProj.x - 15, pendingProj.y); ctx.lineTo(pendingProj.x + 15, pendingProj.y);
      ctx.moveTo(pendingProj.x, pendingProj.y - 15); ctx.lineTo(pendingProj.x, pendingProj.y + 15); ctx.stroke(); ctx.setLineDash([]);
    }
  }

  drawArrowHead(ctx, fromX, fromY, toX, toY, color) {
    const angle = Math.atan2(toY - fromY, toX - fromX); const headLen = 8;
    ctx.fillStyle = color; ctx.beginPath(); ctx.moveTo(toX, toY);
    ctx.lineTo(toX - headLen * Math.cos(angle - 0.4), toY - headLen * Math.sin(angle - 0.4));
    ctx.lineTo(toX - headLen * Math.cos(angle + 0.4), toY - headLen * Math.sin(angle + 0.4));
    ctx.closePath(); ctx.fill();
  }

  drawGrid(ctx, canvasWidth, canvasHeight) {
    const gridSpacing = 50; const gridRange = 300;
    ctx.strokeStyle = '#303050'; ctx.lineWidth = 0.5; ctx.globalAlpha = 0.4;
    for (let i = -gridRange; i <= gridRange; i += gridSpacing) {
      const start = this.projectPoint(i, -gridRange, 0); const end = this.projectPoint(i, gridRange, 0);
      ctx.beginPath(); ctx.moveTo(start.x, start.y); ctx.lineTo(end.x, end.y); ctx.stroke();
      const start2 = this.projectPoint(-gridRange, i, 0); const end2 = this.projectPoint(gridRange, i, 0);
      ctx.beginPath(); ctx.moveTo(start2.x, start2.y); ctx.lineTo(end2.x, end2.y); ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }

  drawOrbit(ctx, mapObj) {
    if (!mapObj.orbit_center_id || !mapObj.orbit_radius) return;

    // Находим координаты центра орбиты (звезды) среди всех объектов
    const { map_objects = [] } = this.props;
    const centerObj = map_objects.find(o => o.id === mapObj.orbit_center_id);
    if (!centerObj) return;

    const centerX = centerObj.position_x;
    const centerY = centerObj.position_y;
    const centerZ = centerObj.position_z || 0;

    ctx.beginPath();
    ctx.strokeStyle = 'rgba(150, 180, 255, 0.07)'; // Очень слабая, чуть голубоватая линия
    ctx.lineWidth = 1;

    const incRad = (mapObj.orbit_inclination || 0) * (Math.PI / 180);
    const ascRad = (mapObj.orbit_ascension || 0) * (Math.PI / 180);

    // Рисуем эллипс (36 точек)
    for (let i = 0; i <= 36; i++) {
      const angle = (i * 10) * (Math.PI / 180);

      // Базовые координаты на плоскости
      let base_x = mapObj.orbit_radius * Math.cos(angle);
      let base_y = mapObj.orbit_radius * Math.sin(angle);
      let base_z = 0;

      // Наклон (X-axis rotation)
      let inc_x = base_x;
      let inc_y = base_y * Math.cos(incRad) - base_z * Math.sin(incRad);
      let inc_z = base_y * Math.sin(incRad) + base_z * Math.cos(incRad);

      // Вращение (Z-axis rotation)
      let final_x = inc_x * Math.cos(ascRad) - inc_y * Math.sin(ascRad);
      let final_y = inc_x * Math.sin(ascRad) + inc_y * Math.cos(ascRad);
      let final_z = inc_z;

      // Смещение относительно звезды
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

  drawHUD(ctx, canvasWidth, canvasHeight) {
    const {
      shuttleAngle = 0, shuttlePitch = 0, shuttleThrust = 0, shuttleHeading = 0, shuttleHeadingPitch = 0,
      shuttleMaxSpeed = 50, shuttleVelX = 0, shuttleVelY = 0, shuttleVelZ = 0, shuttleAlt = 0,
      cameraYaw = 45, cameraPitch = 30, isDocked = false, autopilotEnabled = false, hasPendingTarget = false,
      fuelLevel = 100, fuelMax = 100,
      targetDistance = null, targetETA = null,
      shieldLevel = 100, shieldMax = 100,
      radarStatus = 'ACTIVE',
    } = this.props;

    const velMag = Math.sqrt(shuttleVelX ** 2 + shuttleVelY ** 2 + shuttleVelZ ** 2);

    // === Компас по центру внизу ===
    const compassX = canvasWidth / 2;
    const compassY = canvasHeight - 50;
    const compassRadius = 45;
    this.drawSphereCompass(ctx, compassX, compassY, compassRadius, cameraYaw, cameraPitch,
      shuttleHeading, shuttleHeadingPitch, shuttleThrust, shuttleAngle, velMag, shuttleVelX, shuttleVelY, shuttleVelZ);

    // === Нижняя левая панель: двигатели / топливо ===
    const lx = 10;
    const ly = canvasHeight - 90;
    const pw = 135;
    const ph = 65;
    ctx.fillStyle = 'rgba(0, 0, 0, 0.7)'; ctx.fillRect(lx, ly, pw, ph);
    ctx.strokeStyle = '#333'; ctx.lineWidth = 1; ctx.strokeRect(lx, ly, pw, ph);

    // Топливо
    const fuelPct = fuelMax > 0 ? (fuelLevel / fuelMax) * 100 : 0;
    ctx.fillStyle = '#ffaa00'; ctx.font = 'bold 10px monospace'; ctx.textAlign = 'left';
    ctx.fillText(`FUEL: ${Math.round(fuelPct)}%`, lx + 6, ly + 16);
    ctx.fillStyle = '#332200'; ctx.fillRect(lx + 6, ly + 20, pw - 12, 8);
    ctx.fillStyle = fuelPct > 20 ? '#ffaa00' : '#ff3333';
    ctx.fillRect(lx + 6, ly + 20, (pw - 12) * (fuelPct / 100), 8);

    // Тяга
    ctx.fillStyle = '#ffff00'; ctx.font = 'bold 10px monospace';
    ctx.fillText(`THR: ${shuttleThrust}%`, lx + 6, ly + 42);
    ctx.fillStyle = '#333300'; ctx.fillRect(lx + 6, ly + 46, pw - 12, 8);
    ctx.fillStyle = '#ffff00';
    ctx.fillRect(lx + 6, ly + 46, (pw - 12) * (shuttleThrust / 100), 8);

    // === Нижняя правая панель: навигация / защита ===
    const rx = canvasWidth - 145;
    const ry = canvasHeight - 90;
    ctx.fillStyle = 'rgba(0, 0, 0, 0.7)'; ctx.fillRect(rx, ry, pw, ph);
    ctx.strokeStyle = '#333'; ctx.lineWidth = 1; ctx.strokeRect(rx, ry, pw, ph);

    // Расстояние до цели
    ctx.fillStyle = '#00ff88'; ctx.font = 'bold 10px monospace'; ctx.textAlign = 'left';
    if (targetDistance != null) {
      ctx.fillText(`TGT: ${targetDistance.toFixed(0)} km`, rx + 6, ry + 16);
    } else {
      ctx.fillStyle = '#555';
      ctx.fillText('TGT: --', rx + 6, ry + 16);
    }

    // ETA до цели
    ctx.fillStyle = '#00ff88';
    if (targetETA != null) {
      ctx.fillText(`ETA: ${targetETA}`, rx + 6, ry + 32);
    } else {
      ctx.fillStyle = '#555';
      ctx.fillText('ETA: --', rx + 6, ry + 32);
    }

    // Радар (заглушка)
    ctx.fillStyle = radarStatus === 'ACTIVE' ? '#44ff44' : '#ff4444';
    ctx.fillText(`RDR: ${radarStatus}`, rx + 6, ry + 48);

    // === Статус по центру сверху ===
    if (isDocked) {
      ctx.fillStyle = 'rgba(200, 0, 0, 0.8)'; ctx.font = 'bold 16px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText('DOCKED', canvasWidth / 2, 25);
    } else if (autopilotEnabled) {
      ctx.fillStyle = 'rgba(0, 200, 0, 0.8)'; ctx.font = 'bold 16px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText('AUTOPILOT', canvasWidth / 2, 20);
    } else if (hasPendingTarget) {
      ctx.fillStyle = 'rgba(255, 200, 0, 0.9)'; ctx.font = 'bold 14px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText('COURSE PENDING', canvasWidth / 2, 20);
    }
  }

  drawSphereCompass(ctx, cx, cy, radius, cameraYaw, cameraPitch, shipHeading, shipHeadingPitch, shuttleThrust, shuttleAngle, velMag, velX, velY, velZ) {
    const yawRad = cameraYaw * DEG2RAD; const pitchRad = cameraPitch * DEG2RAD;
    const cosY = Math.cos(yawRad); const sinY = Math.sin(yawRad); const cosP = Math.cos(pitchRad); const sinP = Math.sin(pitchRad);
    const sphereScale = radius * 0.85;
    const rotateToCamera = ({ x, y, z }) => { const x1 = x * cosY - y * sinY; const y1 = x * sinY + y * cosY; const z1 = z; return { x: x1, y: y1 * cosP - z1 * sinP, z: y1 * sinP + z1 * cosP }; };
    const project = ({ x, y, z }) => ({ x: cx + x * sphereScale, y: cy - z * sphereScale, depth: y });
    const projectWorld = (point) => project(rotateToCamera(point));
    const normalize = (v) => { const len = Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z); return len > 0 ? { x: v.x / len, y: v.y / len, z: v.z / len } : { x: 0, y: 0, z: 0 }; };

    ctx.fillStyle = 'rgba(50, 100, 255, 0.2)'; ctx.beginPath(); ctx.arc(cx, cy, sphereScale, 0, Math.PI * 2); ctx.fill();
    const diskFillColor = 'rgba(100, 180, 255, 0.06)'; const diskStrokeColor = 'rgba(150, 200, 255, 0.6)'; const diskLineColor = 'rgba(150, 200, 255, 0.08)';
    this.drawDisk(ctx, projectWorld, diskFillColor, diskStrokeColor, (angle, mult = 1) => ({ x: Math.cos(angle) * mult, y: Math.sin(angle) * mult, z: 0 }));
    this.drawDisk(ctx, projectWorld, diskFillColor, diskLineColor, (angle, mult = 1) => ({ x: Math.cos(angle) * mult, y: 0, z: Math.sin(angle) * mult }));
    this.drawDisk(ctx, projectWorld, diskFillColor, diskLineColor, (angle, mult = 1) => ({ x: 0, y: Math.cos(angle) * mult, z: Math.sin(angle) * mult }));
    this.drawEquatorSegments(ctx, projectWorld, (angle, mult = 1) => ({ x: Math.cos(angle) * mult, y: Math.sin(angle) * mult, z: 0 }));
    this.drawDiskGraduations(ctx, projectWorld, cx, cy, (angle, mult = 1) => ({ x: Math.cos(angle) * mult, y: Math.sin(angle) * mult, z: 0 }), ['0°', '90°', '180°', '270°']);

    const axisScale = 1.15;
    const xPos = projectWorld({ x: axisScale, y: 0, z: 0 }); const xNeg = projectWorld({ x: -axisScale, y: 0, z: 0 });
    ctx.strokeStyle = diskLineColor; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(xNeg.x, xNeg.y); ctx.lineTo(xPos.x, xPos.y); ctx.stroke();
    const yPos = projectWorld({ x: 0, y: axisScale, z: 0 }); const yNeg = projectWorld({ x: 0, y: -axisScale, z: 0 });
    ctx.strokeStyle = diskLineColor; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(yNeg.x, yNeg.y); ctx.lineTo(yPos.x, yPos.y); ctx.stroke();

    const headingRad = shipHeading * DEG2RAD; const pitchHeadingRad = shipHeadingPitch * DEG2RAD;
    const shipDir = normalize({ x: Math.cos(pitchHeadingRad) * Math.cos(headingRad), y: Math.cos(pitchHeadingRad) * Math.sin(headingRad), z: Math.sin(pitchHeadingRad) });
    this.drawArrowAsPyramid(ctx, projectWorld, shipDir, '#00ff80', 0.06, 0.25, true);
    const noseEnd = projectWorld(shipDir);
    ctx.strokeStyle = '#00ff80'; ctx.globalAlpha = 0.3; ctx.lineWidth = 1; ctx.setLineDash([4, 3]); ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(noseEnd.x, noseEnd.y); ctx.stroke(); ctx.setLineDash([]); ctx.globalAlpha = 1;

    if (velMag > 0.5) { const velDir = normalize({ x: velX, y: velY, z: velZ }); this.drawArrowAsPyramid(ctx, projectWorld, velDir, '#00ffff', 0.06, 0.34, false); }
    if (shuttleThrust > 0) {
      const thrustYawRad = shuttleAngle * DEG2RAD; const thrustPitchRad = shipHeadingPitch * DEG2RAD;
      const thrDir = normalize({ x: Math.cos(thrustPitchRad) * Math.cos(thrustYawRad), y: Math.cos(thrustPitchRad) * Math.sin(thrustYawRad), z: Math.sin(thrustPitchRad) });
      const thrEnd = projectWorld(thrDir); ctx.strokeStyle = '#ffff00'; ctx.globalAlpha = 0.5; ctx.lineWidth = 2; ctx.setLineDash([4, 3]); ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(thrEnd.x, thrEnd.y); ctx.stroke(); ctx.setLineDash([]); ctx.globalAlpha = 1;
    }
    ctx.fillStyle = '#aaa'; ctx.font = '9px monospace'; ctx.textAlign = 'center'; ctx.fillText(`PIT: ${Math.round(shipHeadingPitch)}°`, cx, cy + radius + 14);
  }

  drawArrowAsPyramid(ctx, projectWorld, tipDir, color, baseSize = 0.06, height = 0.2, baseAtCenter = false) {
    const tipPoint = baseAtCenter ? { x: tipDir.x * height, y: tipDir.y * height, z: tipDir.z * height } : { x: tipDir.x * (1 + height), y: tipDir.y * (1 + height), z: tipDir.z * (1 + height) };
    let perp1, perp2;
    if (Math.abs(tipDir.x) < 0.9) { perp1 = { x: 0, y: -tipDir.z, z: tipDir.y }; } else { perp1 = { x: -tipDir.z, y: 0, z: tipDir.x }; }
    const len1 = Math.sqrt(perp1.x ** 2 + perp1.y ** 2 + perp1.z ** 2); perp1 = { x: perp1.x / len1, y: perp1.y / len1, z: perp1.z / len1 };
    perp2 = { x: tipDir.y * perp1.z - tipDir.z * perp1.y, y: tipDir.z * perp1.x - tipDir.x * perp1.z, z: tipDir.x * perp1.y - tipDir.y * perp1.x };
    const baseSides = 3; const basePoints = [];
    for (let i = 0; i < baseSides; i++) {
      const angle = (i / baseSides) * Math.PI * 2; const baseX = perp1.x * Math.cos(angle) * baseSize + perp2.x * Math.sin(angle) * baseSize;
      const baseY = perp1.y * Math.cos(angle) * baseSize + perp2.y * Math.sin(angle) * baseSize; const baseZ = perp1.z * Math.cos(angle) * baseSize + perp2.z * Math.sin(angle) * baseSize;
      const pt = baseAtCenter ? { x: baseX, y: baseY, z: baseZ } : { x: tipDir.x + baseX, y: tipDir.y + baseY, z: tipDir.z + baseZ }; basePoints.push(projectWorld(pt));
    }
    const tipProj = projectWorld(tipPoint);
    for (let i = 0; i < baseSides; i++) {
      const next = (i + 1) % baseSides; ctx.fillStyle = color; ctx.globalAlpha = 0.7; ctx.beginPath(); ctx.moveTo(tipProj.x, tipProj.y);
      ctx.lineTo(basePoints[i].x, basePoints[i].y); ctx.lineTo(basePoints[next].x, basePoints[next].y); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = color; ctx.globalAlpha = 0.9; ctx.lineWidth = 1; ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }

  drawDisk(ctx, projectWorld, fillColor, strokeColor, pointFn) {
    const points = []; for (let a = 0; a <= 360; a += 5) { const rad = a * DEG2RAD; points.push(projectWorld(pointFn(rad, 1))); }
    ctx.strokeStyle = strokeColor; ctx.lineWidth = 1; ctx.beginPath(); points.forEach((pt, index) => { if (index === 0) ctx.moveTo(pt.x, pt.y); else ctx.lineTo(pt.x, pt.y); }); ctx.closePath(); ctx.stroke(); ctx.setLineDash([]);
  }

  drawDiskGraduations(ctx, projectWorld, cx, cy, pointFn, labels) {
    const labelRadius = 1.4; const sampleDelta = 0.05;
    const normalize2 = (v) => { const len = Math.hypot(v.x, v.y); return len > 0 ? { x: v.x / len, y: v.y / len } : { x: 1, y: 0 }; };
    ctx.font = '8px sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillStyle = 'rgba(200, 220, 255, 0.9)';
    for (let i = 0; i < 4; i++) {
      const angleDeg = i * 90; const angleRad = angleDeg * DEG2RAD; const center3D = pointFn(angleRad, labelRadius); const labelPos = projectWorld(center3D);
      const screenTangent = projectWorld(pointFn(angleRad + sampleDelta, labelRadius)); const screenRadial = projectWorld(pointFn(angleRad, labelRadius - 0.1));
      const tangentDir = normalize2({ x: screenTangent.x - labelPos.x, y: screenTangent.y - labelPos.y }); const radialDir = normalize2({ x: labelPos.x - screenRadial.x, y: labelPos.y - screenRadial.y });
      ctx.save(); ctx.translate(labelPos.x, labelPos.y); ctx.transform(tangentDir.x, tangentDir.y, radialDir.x, radialDir.y, 0, 0); ctx.fillText(labels[i], 0, 0); ctx.restore();
    }
  }

  drawEquatorSegments(ctx, projectWorld, pointFn) {
    const arcHalfAngle = 10; const offset = 0.12; const angles = [0, 90, 180, 270]; ctx.lineWidth = 1; ctx.lineCap = 'round';
    for (const centerDeg of angles) {
      const steps = 6; const pointsUpper = []; const pointsLower = [];
      for (let s = -steps; s <= steps; s++) {
        const angleRad = (centerDeg + (s / steps) * arcHalfAngle) * DEG2RAD; const base = pointFn(angleRad, 1);
        pointsUpper.push(projectWorld({ x: base.x, y: base.y, z: base.z + offset })); pointsLower.push(projectWorld({ x: base.x, y: base.y, z: base.z - offset }));
      }
      ctx.strokeStyle = 'rgba(200, 220, 255, 0.8)'; ctx.beginPath(); pointsUpper.forEach((pt, idx) => { if (idx === 0) ctx.moveTo(pt.x, pt.y); else ctx.lineTo(pt.x, pt.y); }); ctx.stroke();
      ctx.strokeStyle = 'rgba(140, 160, 200, 0.5)'; ctx.beginPath(); pointsLower.forEach((pt, idx) => { if (idx === 0) ctx.moveTo(pt.x, pt.y); else ctx.lineTo(pt.x, pt.y); }); ctx.stroke();
    }
  }

  handleMouseDown = (e) => {
    if (e.button === 0) {
      e.preventDefault(); this.dragging = true; this.lastDragPos = { x: e.clientX, y: e.clientY };
    } else if (e.button === 2) {
      e.preventDefault();
      if (e.shiftKey) { return; }
      else if (e.ctrlKey) {
        this.adjustingZ = true; this.adjustZStartY = e.clientY;
        const rect = this.canvasRef.getBoundingClientRect(); const clickX = e.clientX - rect.left; const clickY = e.clientY - rect.top;
        const { worldX, worldY } = this.unprojectToGroundPlane(clickX, clickY, 0);
        this.adjustWorldX = worldX; this.adjustWorldY = worldY; this.adjustBaseZ = 0; this.adjustCurrentZ = 0;
        this.localPendingX = worldX; this.localPendingY = worldY; this.localPendingZ = 0;
      } else { this.normalRightClicked = true; }
    }
  };

  handleMouseMove = (e) => {
    if (this.adjustingZ) {
      const dy = e.clientY - this.adjustZStartY; const zScale = 2 / (this.props.zoomScale || 1);
      this.adjustCurrentZ = this.adjustBaseZ - dy * zScale; this.localPendingZ = this.adjustCurrentZ; return;
    }
    if (this.dragging && this.lastDragPos && this.props.onRotate) {
      const dx = e.clientX - this.lastDragPos.x; const dy = e.clientY - this.lastDragPos.y; this.lastDragPos = { x: e.clientX, y: e.clientY }; this.props.onRotate(dx * 0.3, dy * 0.25);
    } else {
      const canvas = this.canvasRef; if (!canvas) return; const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left; const my = e.clientY - rect.top; this.mouseScreenPos = { x: mx, y: my };
      let closestId = null; let closestDist = 15; const { map_objects = [] } = this.props;
      for (const obj of map_objects) {
        const posX = obj.position_x ?? 0; const posY = obj.position_y ?? 0; const posZ = obj.position_z ?? 0;
        const isStatic = obj.render_mode === 'station' || obj.render_mode === 'planet';
        const velX = isStatic ? 0 : (obj.velocity_x ?? 0); const velY = isStatic ? 0 : (obj.velocity_y ?? 0); const velZ = isStatic ? 0 : (obj.velocity_z ?? 0);
        const elapsed = 0.3; const wx = posX + velX * elapsed; const wy = posY + velY * elapsed; const wz = posZ + velZ * elapsed;
        const proj = this.projectPoint(wx, wy, wz); const dx2 = proj.x - mx; const dy2 = proj.y - my; const dist = Math.sqrt(dx2 * dx2 + dy2 * dy2);
        const hitRadius = Math.max(10, (obj.radius || 5) * proj.scale + 5);
        if (dist < hitRadius && dist < closestDist) { closestDist = dist; closestId = obj.id; }
      }
      if (this.hoveredObjectId !== closestId) { this.hoveredObjectId = closestId; canvas.style.cursor = closestId ? 'pointer' : 'grab'; }
    }
  };

  handleMouseUp = (e) => {
    if (e.button === 0) { this.dragging = false; this.lastDragPos = null; }
    else if (e.button === 2) {
      if (this.adjustingZ) {
        this.adjustingZ = false;
        if (this.props.onMapClick) { this.props.onMapClick(this.adjustWorldX, this.adjustWorldY, 'right', false, null, this.adjustCurrentZ); }
        this.localPendingX = null; this.localPendingY = null; this.localPendingZ = null;
      } else if (e.shiftKey) {
        if (this.props.onMapClick) { this.props.onMapClick(0, 0, 'cancel', true, null, 0); }
      } else if (this.normalRightClicked) {
        if (this.props.onMapClick) {
          const rect = this.canvasRef.getBoundingClientRect(); const clickX = e.clientX - rect.left; const clickY = e.clientY - rect.top;
          const { worldX, worldY } = this.unprojectToGroundPlane(clickX, clickY, 0); const objectId = this.hoveredObjectId;
          this.props.onMapClick(worldX, worldY, 'right', false, objectId, 0);
        }
        this.normalRightClicked = false;
      }
    }
  };

  handleWheel = (e) => {
    e.preventDefault(); if (this.props.onZoom) { const delta = e.deltaY > 0 ? 0.9 : 1.1; this.props.onZoom(delta); }
  };

  handleContextMenu = (e) => { e.preventDefault(); };

  handleDoubleClick = (e) => {
    if (!this.props.onMapClick) return; e.preventDefault();
    const rect = this.canvasRef.getBoundingClientRect(); const clickX = e.clientX - rect.left; const clickY = e.clientY - rect.top;
    const { worldX, worldY } = this.unprojectToGroundPlane(clickX, clickY, 0); const objectId = this.hoveredObjectId;
    this.props.onMapClick(worldX, worldY, 'double', e.altKey, objectId, 0);
  };

  render() {
    return (
      <canvas
        ref={(ref) => { this.canvasRef = ref; }}
        style={{ position: 'absolute', width: '100%', height: '100%', cursor: 'grab' }}
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
