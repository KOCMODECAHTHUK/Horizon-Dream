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

    // Perspective projection with zoom as orthographic scale
    const effectiveDist = cameraDistance;
    // Clamp depth to prevent objects behind camera from inverting
    const clampedDepth = Math.max(y2, -effectiveDist * 0.95);
    const perspectiveScale = effectiveDist / (effectiveDist + clampedDepth);
    // Apply zoom as an orthographic scale factor on top of perspective
    const finalScale = perspectiveScale * zoomScale;
    const screenX = (x2 * finalScale) + canvasWidth / 2;
    const screenY = -(z2 * finalScale) + canvasHeight / 2;

    return {
      x: screenX,
      y: screenY,
      depth: y2, // Depth for sorting (further = larger depth)
      scale: finalScale,
    };
  }

  /**
   * Unproject a 2D screen point to 3D world coordinates on the Z=focusZ plane.
   * Uses proper ray-plane intersection.
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

    const effectiveDist = cameraDistance;
    const zoomScaleLocal = zoomScale;

    // Convert screen coords to normalized device coords
    // We need to reverse: screenX = x2 * perspectiveScale * zoomScale + cx
    // So: (screenX - cx) = x2 * (effectiveDist / (effectiveDist + y2)) * zoomScale
    // ndcX = (screenX - cx) / zoomScale  ... but we need to account for zoom
    const ndcX = (screenX - canvasWidth / 2) / zoomScaleLocal;
    const ndcY = -(screenY - canvasHeight / 2) / zoomScaleLocal;

    // Camera position in world space (before rotation, camera is at (0, -effectiveDist, 0))
    const yawRad = cameraYaw * DEG2RAD;
    const pitchRad = cameraPitch * DEG2RAD;
    const cosY = Math.cos(yawRad);
    const sinY = Math.sin(yawRad);
    const cosP = Math.cos(pitchRad);
    const sinP = Math.sin(pitchRad);

    // Camera position in world space:
    // Start at (0, -effectiveDist, 0), then rotate by pitch and yaw
    // After pitch rotation around X: (0, -effectiveDist*cosP, effectiveDist*sinP)
    // After yaw rotation around Z: translate to focus point
    const camLocalX = 0;
    const camLocalY = -effectiveDist;
    const camLocalZ = 0;

    // Camera position in rotated space (after pitch)
    const camPitchY = camLocalY * cosP - camLocalZ * sinP;
    const camPitchZ = camLocalY * sinP + camLocalZ * cosP;

    // Camera position in world space (after yaw, plus focus offset)
    const camWorldX = camLocalX * cosY - camPitchY * sinY + focusX;
    const camWorldY = camLocalX * sinY + camPitchY * cosY + focusY;
    const camWorldZ = camPitchZ + focusZ;

    // Ray direction: from camera through screen point
    // The screen point in view space is (ndcX, 0, ndcY) at depth=0
    // We need to find the ray direction in world space
    // In view space, the ray goes from (0, -effectiveDist, 0) through (ndcX, 0, ndcY)
    // Ray direction in view space: (ndcX, effectiveDist, ndcY) normalized

    // Actually, let's use the inverse projection more directly.
    // We know that projectPoint does:
    // 1. Translate by -focus
    // 2. Rotate yaw
    // 3. Rotate pitch
    // 4. Perspective divide
    // So we need to invert this.

    // For a point on the Z=focusZ plane (worldZ = focusZ):
    // After subtracting focus: rz = 0
    // After yaw: x1, y1
    // After pitch: x2 = x1, y2 = y1*cosP, z2 = y1*sinP
    // Perspective: screenX = x2 * (effDist/(effDist+y2)) + cx
    //             screenY = -z2 * (effDist/(effDist+y2)) + cy

    // So: ndcX = x2 * effDist / (effDist + y2)
    //     ndcY = -z2 * effDist / (effDist + y2)
    // Where: x2 = x1, y2 = y1*cosP, z2 = y1*sinP
    // And: x1 = rx*cosY - ry*sinY, y1 = rx*sinY + ry*cosY, where rx = worldX-focusX, ry = worldY-focusY

    // For z2=0 (on the focusZ plane): y1*sinP = 0 => y1 = 0 (if sinP != 0)
    // Wait, z2 = y1*sinP + rz*cosP, and rz = 0, so z2 = y1*sinP

    // Let's solve properly. We have:
    // ndcX = x2 * s where s = effDist/(effDist+y2)
    // ndcY = -z2 * s

    // x2 = x1 = (worldX-focusX)*cosY - (worldY-focusY)*sinY
    // y2 = y1*cosP - 0*sinP = y1*cosP = ((worldX-focusX)*sinY + (worldY-focusY)*cosY)*cosP
    // z2 = y1*sinP + 0*cosP = y1*sinP

    // From ndcY: ndcY = -y1*sinP * s = -y1*sinP * effDist/(effDist + y1*cosP)
    // From ndcX: ndcX = x1 * s = x1 * effDist/(effDist + y1*cosP)

    // Let's denote y1 = ((worldX-focusX)*sinY + (worldY-focusY)*cosY)
    // We need to find worldX, worldY on the Z=focusZ plane.

    // Step 1: Find y1 from ndcY
    // ndcY = -y1*sinP * effDist / (effDist + y1*cosP)
    // ndcY * (effDist + y1*cosP) = -y1*sinP*effDist
    // ndcY*effDist + ndcY*y1*cosP = -y1*sinP*effDist
    // ndcY*effDist = -y1*sinP*effDist - ndcY*y1*cosP
    // ndcY*effDist = -y1*(sinP*effDist + ndcY*cosP)
    // y1 = -ndcY*effDist / (sinP*effDist + ndcY*cosP)

    const denom = sinP * effectiveDist + ndcY * cosP;
    let y1;
    if (Math.abs(denom) < 0.001) {
      // Nearly horizontal view - can't determine depth, use approximate
      y1 = 0;
    } else {
      y1 = -ndcY * effectiveDist / denom;
    }

    // Step 2: Find x1 from ndcX
    // ndcX = x1 * effDist / (effDist + y1*cosP)
    const s = effectiveDist / (effectiveDist + y1 * cosP);
    const x1 = ndcX / s;

    // Step 3: Rotate back from view space to world space (inverse yaw)
    // x1 = rx*cosY - ry*sinY
    // y1 = rx*sinY + ry*cosY
    // Solve for rx, ry:
    const rx = x1 * cosY + y1 * sinY;
    const ry = -x1 * sinY + y1 * cosY;

    // Step 4: Add focus offset
    const worldX = rx + focusX;
    const worldY = ry + focusY;

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
        // Planet: sphere with gradient shading
        const planetRadius = Math.max(8, (obj.radius || 20) * projected.scale);

        // Glow behind planet
        ctx.globalAlpha = 0.2;
        const glowGradient = ctx.createRadialGradient(
          ground.x, ground.y, 0,
          ground.x, ground.y, planetRadius * 1.5
        );
        glowGradient.addColorStop(0, color);
        glowGradient.addColorStop(1, 'transparent');
        ctx.fillStyle = glowGradient;
        ctx.beginPath();
        ctx.arc(ground.x, ground.y, planetRadius * 1.5, 0, Math.PI * 2);
        ctx.fill();
        ctx.globalAlpha = 1;

        // Sphere gradient (light from top-left)
        const sphereGradient = ctx.createRadialGradient(
          projected.x - r * 0.3, projected.y - r * 0.3, r * 0.2,
          projected.x, projected.y, r
        );
        sphereGradient.addColorStop(0, lightenColor(color, 40));
        sphereGradient.addColorStop(0.3, color);
        sphereGradient.addColorStop(1, darkenColor(color, 40));

        ctx.fillStyle = sphereGradient;
        ctx.beginPath();
        ctx.arc(projected.x, projected.y, planetRadius, 0, Math.PI * 2);
        ctx.fill();

        // Atmosphere glow
        ctx.strokeStyle = color;
        ctx.lineWidth = 2;
        ctx.globalAlpha = 0.4;
        ctx.beginPath();
        ctx.arc(projected.x, projected.y, planetRadius, 0, Math.PI * 2);
        ctx.stroke();
        ctx.globalAlpha = 1;
      } else if (isOurShuttle) {
        // Our shuttle: triangle oriented by heading
        const shuttleWidth = r * 2;
        const shuttleHeight = r * 1.5;

        // Calculate rotation from heading angle (convert to radians, 0 = right)
        const headingRad = ((shuttleHeading || 0) - 90) * DEG2RAD;

        ctx.save();
        ctx.translate(projected.x, projected.y);
        ctx.rotate(headingRad);

        // Shuttle body (triangle pointing up in local coords)
        ctx.fillStyle = color || SHIP_COLOR;
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 1.5;

        // Draw triangle centered at origin, pointing up
        ctx.beginPath();
        ctx.moveTo(0, -shuttleHeight);  // Nose (top)
        ctx.lineTo(-shuttleWidth * 0.5, shuttleHeight * 0.5);  // Back left
        ctx.lineTo(shuttleWidth * 0.5, shuttleHeight * 0.5);  // Back right
        ctx.closePath();
        ctx.fill();
        ctx.stroke();

        // Engine glow when thrusting
        if (shuttleThrust > 0) {
          const flicker = 0.6 + 0.4 * Math.sin(Date.now() / 100);
          ctx.globalAlpha = flicker;
          ctx.fillStyle = '#ff6600';
          ctx.beginPath();
          ctx.moveTo(-shuttleWidth * 0.3, shuttleHeight * 0.3);
          ctx.lineTo(-shuttleWidth * 0.5, shuttleHeight * 0.8 + shuttleThrust * 0.05);
          ctx.lineTo(shuttleWidth * 0.5, shuttleHeight * 0.8 + shuttleThrust * 0.05);
          ctx.lineTo(shuttleWidth * 0.3, shuttleHeight * 0.3);
          ctx.closePath();
          ctx.fill();
          ctx.globalAlpha = 1;
        }

        ctx.restore();
      } else {
        // Other shuttle or object: simple triangle
        const objWidth = r * 1.5;
        const objHeight = r * 1.2;
        const objHeading = ((obj.heading || 0) - 90) * DEG2RAD;

        ctx.save();
        ctx.translate(projected.x, projected.y);
        ctx.rotate(objHeading);

        ctx.fillStyle = color || '#888';
        ctx.strokeStyle = color || '#888';
        ctx.lineWidth = 1;

        ctx.beginPath();
        ctx.moveTo(0, -objHeight);
        ctx.lineTo(-objWidth * 0.5, objHeight * 0.5);
        ctx.lineTo(objWidth * 0.5, objHeight * 0.5);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();

        ctx.restore();
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

        // Draw heading indicator (white triangle showing nose direction)
        // This persists even when thrust is 0
        const headingRad = shuttleHeading * DEG2RAD;
        const headingPitchRad = shuttleHeadingPitch * DEG2RAD;
        const headingScale = 20;
        const fwdX = Math.cos(headingRad) * Math.cos(headingPitchRad);
        const fwdY = Math.sin(headingRad) * Math.cos(headingPitchRad);
        const fwdZ = Math.sin(headingPitchRad);
        const headingEnd = this.projectPoint(
          worldX + fwdX * headingScale,
          worldY + fwdY * headingScale,
          worldZ + fwdZ * headingScale
        );

        // Draw heading line (white dashed)
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 2;
        ctx.setLineDash([5, 3]);
        ctx.beginPath();
        ctx.moveTo(projected.x, projected.y);
        ctx.lineTo(headingEnd.x, headingEnd.y);
        ctx.stroke();
        ctx.setLineDash([]);

        // Draw heading triangle at the tip
        const triAngle = Math.atan2(headingEnd.y - projected.y, headingEnd.x - projected.x);
        ctx.fillStyle = '#ffffff';
        ctx.beginPath();
        ctx.moveTo(headingEnd.x, headingEnd.y);
        ctx.lineTo(
          headingEnd.x - 8 * Math.cos(triAngle - 0.4),
          headingEnd.y - 8 * Math.sin(triAngle - 0.4)
        );
        ctx.lineTo(
          headingEnd.x - 8 * Math.cos(triAngle + 0.4),
          headingEnd.y - 8 * Math.sin(triAngle + 0.4)
        );
        ctx.closePath();
        ctx.fill();

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

    // Draw hovered object highlight
    if (this.hoveredObjectId) {
      const hovItem = drawItems.find(i => i.obj && i.obj.id === this.hoveredObjectId);
      if (hovItem) {
        const hr = Math.max(6, (hovItem.obj.radius || 5) * hovItem.projected.scale + 4);
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 2;
        ctx.globalAlpha = 0.8;
        ctx.beginPath();
        ctx.arc(hovItem.projected.x, hovItem.projected.y, hr, 0, Math.PI * 2);
        ctx.stroke();
        ctx.globalAlpha = 1;

        // Info tooltip near object
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
        ctx.fillText(`X:${hovItem.worldX.toFixed(0)} Y:${hovItem.worldY.toFixed(0)}`, tipX + 4, tipY + 28);
        ctx.fillText(`Z:${hovItem.worldZ.toFixed(0)} R:${hovItem.obj.radius || 5}`, tipX + 4, tipY + 40);
      }
    }

    // Draw HUD overlay
    this.drawHUD(ctx, canvasWidth, canvasHeight);
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
    // Replaced by mini-altimeter in HUD
  }

  /**
   * Draw Homeworld-style HUD overlay: 3D sphere compass at bottom center, speed indicators
   */
  drawHUD(ctx, canvasWidth, canvasHeight) {
    const {
      shuttleAngle = 0,
      shuttlePitch = 0,
      shuttleThrust = 0,
      shuttleHeading = 0,
      shuttleHeadingPitch = 0,
      shuttleMaxSpeed = 50,
      shuttleVelX = 0,
      shuttleVelY = 0,
      shuttleVelZ = 0,
      shuttleAlt = 0,
      cameraYaw = 45,
      cameraPitch = 30,
      isDocked = false,
      autopilotEnabled = false,
      ourObject = null,
    } = this.props;

    const velMag = Math.sqrt(shuttleVelX * shuttleVelX + shuttleVelY * shuttleVelY + shuttleVelZ * shuttleVelZ);

    // === Bottom-center: 3D Sphere Compass ===
    const compassX = canvasWidth / 2;
    const compassY = canvasHeight - 50;
    const compassRadius = 45;
    this.drawSphereCompass(
      ctx,
      compassX,
      compassY,
      compassRadius,
      cameraYaw,
      cameraPitch,
      shuttleHeading,
      shuttleHeadingPitch,
      shuttleThrust,
      shuttleAngle,
      velMag,
      shuttleVelX,
      shuttleVelY,
      shuttleVelZ
    );

    // === Top-left: Speed & thrust info ===
    const bx = 10;
    const by = 10;
    ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
    ctx.fillRect(bx, by, 140, 70);
    ctx.strokeStyle = '#333';
    ctx.lineWidth = 1;
    ctx.strokeRect(bx, by, 140, 70);

    // Speed
    ctx.fillStyle = '#00ffff';
    ctx.font = 'bold 11px monospace';
    ctx.textAlign = 'left';
    ctx.fillText(`SPD: ${velMag.toFixed(1)} km/s`, bx + 6, by + 18);

    // Speed bar
    const speedFrac = Math.min(velMag / shuttleMaxSpeed, 1);
    ctx.fillStyle = '#004444';
    ctx.fillRect(bx + 6, by + 24, 128, 8);
    ctx.fillStyle = velMag >= shuttleMaxSpeed * 0.9 ? '#ff4444' : '#00ffff';
    ctx.fillRect(bx + 6, by + 24, 128 * speedFrac, 8);

    // Thrust
    ctx.fillStyle = shuttleThrust > 0 ? '#ffff00' : '#666';
    ctx.fillText(`THR: ${shuttleThrust}%`, bx + 6, by + 48);

    // Thrust bar
    ctx.fillStyle = '#444400';
    ctx.fillRect(bx + 6, by + 54, 128, 8);
    ctx.fillStyle = shuttleThrust > 0 ? '#ffff00' : '#666';
    ctx.fillRect(bx + 6, by + 54, 128 * (shuttleThrust / 100), 8);

    // Altitude
    ctx.fillStyle = '#ff88ff';
    ctx.fillText(`ALT: ${shuttleAlt >= 0 ? '+' : ''}${shuttleAlt.toFixed(0)}`, bx + 6, by + 66);

    // === Top-right: Heading & Pitch numeric ===
    const tx = canvasWidth - 150;
    const ty = 10;
    ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
    ctx.fillRect(tx, ty, 140, 50);
    ctx.strokeStyle = '#333';
    ctx.lineWidth = 1;
    ctx.strokeRect(tx, ty, 140, 50);

    ctx.fillStyle = '#ffffff';
    ctx.font = 'bold 11px monospace';
    ctx.textAlign = 'left';
    ctx.fillText(`HDG: ${Math.round(shuttleHeading)}°`, tx + 6, ty + 20);
    ctx.fillText(`PIT: ${Math.round(shuttleHeadingPitch)}°`, tx + 6, ty + 38);

    // === Status indicator ===
    if (isDocked) {
      ctx.fillStyle = 'rgba(200, 0, 0, 0.8)';
      ctx.font = 'bold 16px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('DOCKED', canvasWidth / 2, 25);
    } else if (autopilotEnabled) {
      ctx.fillStyle = 'rgba(0, 200, 0, 0.8)';
      ctx.font = 'bold 16px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('AUTOPILOT ACTIVE', canvasWidth / 2, 25);
    }
  }

  /**
   * Draw 3D sphere compass at bottom center
   * Shows ship orientation as a 3D wireframe sphere with heading indicator
   */
  drawSphereCompass(ctx, cx, cy, radius, cameraYaw, cameraPitch, shipHeading, shipHeadingPitch, shuttleThrust, shuttleAngle, velMag, velX, velY, velZ) {
    const yawRad = cameraYaw * DEG2RAD;
    const pitchRad = cameraPitch * DEG2RAD;
    const cosY = Math.cos(yawRad);
    const sinY = Math.sin(yawRad);
    const cosP = Math.cos(pitchRad);
    const sinP = Math.sin(pitchRad);
    const sphereScale = radius * 0.85;

    const rotateToCamera = ({ x, y, z }) => {
      const x1 = x * cosY - y * sinY;
      const y1 = x * sinY + y * cosY;
      const z1 = z;
      return {
        x: x1,
        y: y1 * cosP - z1 * sinP,
        z: y1 * sinP + z1 * cosP,
      };
    };

    const project = ({ x, y, z }) => ({
      x: cx + x * sphereScale,
      y: cy - z * sphereScale,
      depth: y,
    });

    const projectWorld = (point) => project(rotateToCamera(point));

    const drawArrow = (end, color, width = 2, dash = []) => {
      ctx.strokeStyle = color;
      ctx.fillStyle = color;
      ctx.lineWidth = width;
      if (dash.length) ctx.setLineDash(dash);
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(end.x, end.y);
      ctx.stroke();
      if (dash.length) ctx.setLineDash([]);

      const angle = Math.atan2(end.y - cy, end.x - cx);
      const headSize = 6;
      ctx.beginPath();
      ctx.moveTo(end.x, end.y);
      ctx.lineTo(end.x - headSize * Math.cos(angle - 0.4), end.y - headSize * Math.sin(angle - 0.4));
      ctx.lineTo(end.x - headSize * Math.cos(angle + 0.4), end.y - headSize * Math.sin(angle + 0.4));
      ctx.closePath();
      ctx.fill();
    };

    const normalize = (v) => {
      const len = Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
      return len > 0 ? { x: v.x / len, y: v.y / len, z: v.z / len } : { x: 0, y: 0, z: 0 };
    };

    // Background glow
    const glowGradient = ctx.createRadialGradient(cx, cy, radius * 0.5, cx, cy, radius * 1.3);
    glowGradient.addColorStop(0, 'rgba(13, 153, 222, 0.3)');
    glowGradient.addColorStop(1, 'transparent');
    ctx.fillStyle = glowGradient;
    ctx.beginPath();
    ctx.arc(cx, cy, radius * 1.3, 0, Math.PI * 2);
    ctx.fill();

  // Это неплохо, но позже вернуться к этому - для стиля пока выключено
  //  // Sphere background
  //  ctx.fillStyle = 'rgba(0, 20, 40, 0.85)';
  //  ctx.beginPath();
  //  ctx.arc(cx, cy, radius, 0, Math.PI * 2);
  //  ctx.fill();

    // ===== THREE NEUTRAL DISKS =====
    const diskFillColor = 'rgba(100, 180, 255, 0.06)';
    const diskStrokeColor = 'rgba(150, 200, 255, 0.3)';

    // XY disk (horizontal) — with degree labels
    this.drawDisk(ctx, projectWorld, diskFillColor, diskStrokeColor,
      (angle, mult = 1) => ({ x: Math.cos(angle) * mult, y: Math.sin(angle) * mult, z: 0 })
    );
    this.drawDiskGraduations(ctx, projectWorld, cx, cy,
      (angle, mult = 1) => ({ x: Math.cos(angle) * mult, y: Math.sin(angle) * mult, z: 0 }),
      ['0°', '90°', '180°', '270°']
    );

    // XZ disk (vertical through X-Z) — no labels, just ticks
    this.drawDisk(ctx, projectWorld, diskFillColor, diskStrokeColor,
      (angle, mult = 1) => ({ x: Math.cos(angle) * mult, y: 0, z: Math.sin(angle) * mult })
    );

    // YZ disk (vertical through Y-Z) — no labels, just ticks
    this.drawDisk(ctx, projectWorld, diskFillColor, diskStrokeColor,
      (angle, mult = 1) => ({ x: 0, y: Math.cos(angle) * mult, z: Math.sin(angle) * mult })
    );
    // ===== COLORED AXES =====
    const axisScale = 1.15;

    // X axis (red)
    const xPos = projectWorld({ x: axisScale, y: 0, z: 0 });
    const xNeg = projectWorld({ x: -axisScale, y: 0, z: 0 });
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(xNeg.x, xNeg.y);
    ctx.lineTo(xPos.x, xPos.y);
    ctx.stroke();

    // Y axis (green)
    const yPos = projectWorld({ x: 0, y: axisScale, z: 0 });
    const yNeg = projectWorld({ x: 0, y: -axisScale, z: 0 });
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(yNeg.x, yNeg.y);
    ctx.lineTo(yPos.x, yPos.y);
    ctx.stroke();

    // Z axis (blue)
    const zPos = projectWorld({ x: 0, y: 0, z: axisScale });
    const zNeg = projectWorld({ x: 0, y: 0, z: -axisScale });
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(zNeg.x, zNeg.y);
    ctx.lineTo(zPos.x, zPos.y);
    ctx.stroke();


    // Ship heading vector
    const headingRad = shipHeading * DEG2RAD;
    const pitchHeadingRad = shipHeadingPitch * DEG2RAD;
    const shipDir = normalize({
      x: Math.cos(pitchHeadingRad) * Math.cos(headingRad),
      y: Math.cos(pitchHeadingRad) * Math.sin(headingRad),
      z: Math.sin(pitchHeadingRad),
    });
    const shipEnd = projectWorld(shipDir);
    drawArrow(shipEnd, '#00ff80', 3);
    ctx.fillStyle = '#00ff80';
    ctx.font = 'bold 9px sans-serif';
    ctx.fillText('NOSE', shipEnd.x, shipEnd.y - 12);

    // Velocity vector
    if (velMag > 0.5) {
      const velDir = normalize({ x: velX, y: velY, z: velZ });
      const velEnd = projectWorld(velDir);
      drawArrow(velEnd, '#00ffff', 2, [3, 3]);
      ctx.fillStyle = '#00ffff';
      ctx.font = '9px sans-serif';
      ctx.fillText('VEL', velEnd.x, velEnd.y - 12);
    }

    // Thrust vector
    if (shuttleThrust > 0) {
      const thrustYawRad = shuttleAngle * DEG2RAD;
      const thrustPitchRad = shipHeadingPitch * DEG2RAD;
      const thrDir = normalize({
        x: Math.cos(thrustPitchRad) * Math.cos(thrustYawRad),
        y: Math.cos(thrustPitchRad) * Math.sin(thrustYawRad),
        z: Math.sin(thrustPitchRad),
      });
      const thrEnd = projectWorld(thrDir);
      drawArrow(thrEnd, '#ffff00', 2, [5, 4]);
      ctx.fillStyle = '#ffff00';
      ctx.font = '9px sans-serif';
      ctx.fillText('THR', thrEnd.x, thrEnd.y + 14);
    }

    // Center dot
    ctx.fillStyle = 'rgba(255, 255, 255, 0.9)';
    ctx.beginPath();
    ctx.arc(cx, cy, 3.5, 0, Math.PI * 2);
    ctx.fill();

    // Pitch text below sphere
    ctx.fillStyle = '#aaa';
    ctx.font = '9px monospace';
    ctx.textAlign = 'center';
    ctx.fillText(`PIT: ${Math.round(shipHeadingPitch)}°`, cx, cy + radius + 14);
  }

  /**
   * Draw a single disk on the sphere compass
   */
  drawDisk(ctx, projectWorld, fillColor, strokeColor, pointFn) {
    const points = [];
    for (let a = 0; a <= 360; a += 5) {
      const rad = a * DEG2RAD;
      points.push(projectWorld(pointFn(rad, 1)));
    }

    // Fill disk
    ctx.fillStyle = fillColor;
    ctx.beginPath();
    points.forEach((pt, index) => {
      if (index === 0) ctx.moveTo(pt.x, pt.y);
      else ctx.lineTo(pt.x, pt.y);
    });
    ctx.closePath();
    ctx.fill();

    // Stroke disk edge
    ctx.strokeStyle = strokeColor;
    ctx.lineWidth = 1;
    ctx.setLineDash([4, 4]);
    ctx.beginPath();
    points.forEach((pt, index) => {
      if (index === 0) ctx.moveTo(pt.x, pt.y);
      else ctx.lineTo(pt.x, pt.y);
    });
    ctx.closePath();
    ctx.stroke();
    ctx.setLineDash([]);
  }

  /**
    * Draw degree labels ON the disk plane — they project with the same 3D transform,
    * so they become less visible when the disk is viewed edge-on.
    */
  drawDiskGraduations(ctx, projectWorld, cx, cy, pointFn, labels) {
    const labelRadius = 1.4;  // Farther from the disk edge, still on the plane
    const tickOuter = 1.05;
    const tickInner = 0.94;
    const sampleDelta = 0.05;

    const normalize2 = (v) => {
      const len = Math.hypot(v.x, v.y);
      return len > 0 ? { x: v.x / len, y: v.y / len } : { x: 1, y: 0 };
    };

    ctx.font = '8px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = 'rgba(200, 220, 255, 0.9)';

    // Major ticks and labels every 90°
    for (let i = 0; i < 4; i++) {
      const angleDeg = i * 90;
      const angleRad = angleDeg * DEG2RAD;

      // Tick mark — on the plane
      const outer = projectWorld(pointFn(angleRad, tickOuter));
      const inner = projectWorld(pointFn(angleRad, tickInner));
      ctx.strokeStyle = 'rgba(200, 220, 255, 0.8)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(outer.x, outer.y);
      ctx.lineTo(inner.x, inner.y);
      ctx.stroke();

      const center3D = pointFn(angleRad, labelRadius);
      const labelPos = projectWorld(center3D);

      // Project small offsets in the plane to get local axes in screen space
      const screenTangent = projectWorld(pointFn(angleRad + sampleDelta, labelRadius));
      const screenRadial = projectWorld(pointFn(angleRad, labelRadius - 0.1));

      const tangentDir = normalize2({ x: screenTangent.x - labelPos.x, y: screenTangent.y - labelPos.y });
      const radialDir = normalize2({ x: labelPos.x - screenRadial.x, y: labelPos.y - screenRadial.y });

      ctx.save();
      ctx.translate(labelPos.x, labelPos.y);
      ctx.transform(tangentDir.x, tangentDir.y, radialDir.x, radialDir.y, 0, 0);
      ctx.fillText(labels[i], 0, 0);
      ctx.restore();
    }
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
    if (this.dragging && this.lastDragPos && this.props.onRotate) {
      const dx = e.clientX - this.lastDragPos.x;
      const dy = e.clientY - this.lastDragPos.y;
      this.lastDragPos = { x: e.clientX, y: e.clientY };
      this.props.onRotate(dx * 0.3, dy * 0.25);
    } else {
      // Hover detection
      const canvas = this.canvasRef;
      if (!canvas) return;
      const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left;
      const my = e.clientY - rect.top;
      this.mouseScreenPos = { x: mx, y: my };

      // Find closest object under cursor
      const dpr = window.devicePixelRatio || 1;
      let closestId = null;
      let closestDist = 15; // pixel threshold
      const { map_objects = [], ourObject = null, focusX = 0, focusY = 0, focusZ = 0 } = this.props;
      for (const obj of map_objects) {
        const posX = obj.position_x ?? 0;
        const posY = obj.position_y ?? 0;
        const posZ = obj.position_z ?? 0;
        const isStatic = obj.render_mode === 'station' || obj.render_mode === 'planet';
        const velX = isStatic ? 0 : (obj.velocity_x ?? 0);
        const velY = isStatic ? 0 : (obj.velocity_y ?? 0);
        const velZ = isStatic ? 0 : (obj.velocity_z ?? 0);
        const elapsed = 0.3;
        const wx = posX + velX * elapsed;
        const wy = posY + velY * elapsed;
        const wz = posZ + velZ * elapsed;
        const proj = this.projectPoint(wx, wy, wz);
        const dx2 = proj.x - mx;
        const dy2 = proj.y - my;
        const dist = Math.sqrt(dx2 * dx2 + dy2 * dy2);
        const hitRadius = Math.max(10, (obj.radius || 5) * proj.scale + 5);
        if (dist < hitRadius && dist < closestDist) {
          closestDist = dist;
          closestId = obj.id;
        }
      }
      if (this.hoveredObjectId !== closestId) {
        this.hoveredObjectId = closestId;
        canvas.style.cursor = closestId ? 'pointer' : 'grab';
      }
    }
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

    // Check if clicking on an object
    const objectId = this.hoveredObjectId;

    this.props.onMapClick(worldX, worldY, 'right', e.altKey, objectId);
  };

  handleDoubleClick = (e) => {
    if (!this.props.onMapClick) return;
    e.preventDefault();

    const rect = this.canvasRef.getBoundingClientRect();
    const clickX = e.clientX - rect.left;
    const clickY = e.clientY - rect.top;
    const { worldX, worldY, worldZ } = this.unprojectToGroundPlane(clickX, clickY);

    const objectId = this.hoveredObjectId;

    this.props.onMapClick(worldX, worldY, 'double', e.altKey, objectId);
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
