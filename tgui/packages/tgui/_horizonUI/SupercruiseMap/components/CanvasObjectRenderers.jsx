import { DEG2RAD, lightenColor, darkenColor } from './MapUtils';

const SHIP_COLOR = '#a4eea4';

/**
 * Отрисовка стрелки (наконечника вектора)
 */
export function drawArrowHead(ctx, fromX, fromY, toX, toY, color) {
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

/**
 * Отрисовка линии высоты (от объекта до Z=0)
 */
export function drawAltitudeLine(ctx, item) {
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

/**
 * Отрисовка следа истории позиций (только для нашего шаттла)
 */
function drawHistoryTrail(ctx, item, projectPoint) {
  const { obj, isOurShuttle } = item;
  if (!isOurShuttle || !obj.position_history || obj.position_history.length <= 1) return;

  ctx.strokeStyle = '#a4eea4';
  ctx.lineWidth = 1.5;
  ctx.globalAlpha = 0.4;
  ctx.beginPath();

  const history = obj.position_history;
  for (let i = 0; i < history.length; i++) {
    const pos = history[i];
    const hx = Array.isArray(pos) ? (pos[0] || pos[1] || 0) : (pos.x || 0);
    const hy = Array.isArray(pos) ? (pos[1] || pos.y || 0) : (pos.y || 0);
    const hz = Array.isArray(pos) ? (pos[2] || pos[3] || 0) : (pos.z || 0);
    const hProj = projectPoint(hx, hy, hz);
    if (i === 0) ctx.moveTo(hProj.x, hProj.y);
    else ctx.lineTo(hProj.x, hProj.y);
  }
  ctx.stroke();
  ctx.globalAlpha = 1;
}

/**
 * Отрисовка станции
 */
function drawStation(ctx, item, r) {
  const { obj, projected, ground, color } = item;
  const dockingRange = (obj.docking_range || 20) * projected.scale;

  ctx.strokeStyle = '#88aaff';
  ctx.lineWidth = 1;
  ctx.globalAlpha = 0.3;
  ctx.setLineDash([5, 5]);
  ctx.beginPath();
  ctx.arc(ground.x, ground.y, dockingRange, 0, Math.PI * 2);
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.globalAlpha = 1;

  const halfR = r * 0.7;
  ctx.fillStyle = color;
  ctx.strokeStyle = '#88aaff';
  ctx.lineWidth = 2;
  ctx.fillRect(projected.x - halfR, projected.y - halfR, halfR * 2, halfR * 2);
  ctx.strokeRect(projected.x - halfR, projected.y - halfR, halfR * 2, halfR * 2);
}

/**
 * Отрисовка планеты
 */
function drawPlanet(ctx, item, r) {
  const { projected, ground, color } = item;
  const planetRadius = Math.max(8, (item.obj.radius || 20) * projected.scale);

  ctx.globalAlpha = 0.2;
  const glowGradient = ctx.createRadialGradient(ground.x, ground.y, 0, ground.x, ground.y, planetRadius * 1.5);
  glowGradient.addColorStop(0, color);
  glowGradient.addColorStop(1, 'transparent');
  ctx.fillStyle = glowGradient;
  ctx.beginPath();
  ctx.arc(ground.x, ground.y, planetRadius * 1.5, 0, Math.PI * 2);
  ctx.fill();
  ctx.globalAlpha = 1;

  const sphereGradient = ctx.createRadialGradient(projected.x - r * 0.3, projected.y - r * 0.3, r * 0.2, projected.x, projected.y, r);
  sphereGradient.addColorStop(0, lightenColor(color, 40));
  sphereGradient.addColorStop(0.3, color);
  sphereGradient.addColorStop(1, darkenColor(color, 40));
  ctx.fillStyle = sphereGradient;
  ctx.beginPath();
  ctx.arc(projected.x, projected.y, planetRadius, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = color;
  ctx.lineWidth = 2;
  ctx.globalAlpha = 0.4;
  ctx.beginPath();
  ctx.arc(projected.x, projected.y, planetRadius, 0, Math.PI * 2);
  ctx.stroke();
  ctx.globalAlpha = 1;
}

/**
 * Отрисовка звезды / солнца
 */
function drawStar(ctx, item, r) {
  const { projected } = item;
  const starRadius = Math.max(15, (item.obj.radius || 40) * projected.scale);

  ctx.save();
  ctx.globalCompositeOperation = 'lighter';

  ctx.globalAlpha = 0.15;
  const corona = ctx.createRadialGradient(projected.x, projected.y, 0, projected.x, projected.y, starRadius * 5);
  corona.addColorStop(0, '#ff8800');
  corona.addColorStop(0.4, 'rgba(255, 100, 0, 0.05)');
  corona.addColorStop(1, 'transparent');
  ctx.fillStyle = corona;
  ctx.beginPath();
  ctx.arc(projected.x, projected.y, starRadius * 5, 0, Math.PI * 2);
  ctx.fill();

  ctx.globalAlpha = 0.4;
  const bloom = ctx.createRadialGradient(projected.x, projected.y, 0, projected.x, projected.y, starRadius * 2);
  bloom.addColorStop(0, '#ffffcc');
  bloom.addColorStop(0.5, 'rgba(255, 200, 50, 0.3)');
  bloom.addColorStop(1, 'transparent');
  ctx.fillStyle = bloom;
  ctx.beginPath();
  ctx.arc(projected.x, projected.y, starRadius * 2, 0, Math.PI * 2);
  ctx.fill();

  ctx.globalAlpha = 0.9;
  const core = ctx.createRadialGradient(projected.x, projected.y, 0, projected.x, projected.y, starRadius * 1.2);
  core.addColorStop(0, '#ffffff');
  core.addColorStop(0.2, '#ffffee');
  core.addColorStop(0.6, '#ffcc00');
  core.addColorStop(1, 'transparent');
  ctx.fillStyle = core;
  ctx.beginPath();
  ctx.arc(projected.x, projected.y, starRadius * 1.2, 0, Math.PI * 2);
  ctx.fill();

  ctx.restore();
}

/**
 * Отрисовка нашего шаттла
 */
function drawShuttle(ctx, item, r, shuttleHeading, shuttleThrust) {
  const { projected, color } = item;
  const shuttleWidth = r * 2;
  const shuttleHeight = r * 1.5;
  const headingRad = ((shuttleHeading || 0) - 90) * DEG2RAD;

  ctx.save();
  ctx.translate(projected.x, projected.y);
  ctx.rotate(headingRad);
  ctx.fillStyle = color || SHIP_COLOR;
  ctx.strokeStyle = '#ffffff';
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(0, -shuttleHeight);
  ctx.lineTo(-shuttleWidth * 0.5, shuttleHeight * 0.5);
  ctx.lineTo(shuttleWidth * 0.5, shuttleHeight * 0.5);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

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
}

/**
 * Отрисовка стандартного объекта (чужой корабль, астероид)
 */
function drawGenericObject(ctx, item, r) {
  const { obj, projected, color } = item;
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

/**
 * Отрисовка векторов скорости, курса и тяги (только для нашего шаттла)
 */
function drawShuttleVectors(ctx, item, props, projectPoint) {
  const { obj, projected, worldX, worldY, worldZ } = item;
  const { shuttleHeading, shuttleHeadingPitch, shuttleThrust } = props;

  // Вектор скорости
  const velX2 = obj.velocity_x ?? 0;
  const velY2 = obj.velocity_y ?? 0;
  const velZ2 = obj.velocity_z ?? 0;
  const velMag = Math.sqrt(velX2 * velX2 + velY2 * velY2 + velZ2 * velZ2);
  if (velMag > 0.5) {
    const velScale = 3;
    const velEnd = projectPoint(worldX + velX2 * velScale, worldY + velY2 * velScale, worldZ + velZ2 * velScale);
    ctx.strokeStyle = '#00ffff';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(projected.x, projected.y);
    ctx.lineTo(velEnd.x, velEnd.y);
    ctx.stroke();
    drawArrowHead(ctx, projected.x, projected.y, velEnd.x, velEnd.y, '#00ffff');
  }

  // Вектор курса (Heading)
  const headingRad = shuttleHeading * DEG2RAD;
  const headingPitchRad = shuttleHeadingPitch * DEG2RAD;
  const headingScale = 20;
  const fwdX = Math.cos(headingRad) * Math.cos(headingPitchRad);
  const fwdY = Math.sin(headingRad) * Math.cos(headingPitchRad);
  const fwdZ = Math.sin(headingPitchRad);
  const headingEnd = projectPoint(worldX + fwdX * headingScale, worldY + fwdY * headingScale, worldZ + fwdZ * headingScale);

  ctx.strokeStyle = '#ffffff';
  ctx.lineWidth = 2;
  ctx.setLineDash([5, 3]);
  ctx.beginPath();
  ctx.moveTo(projected.x, projected.y);
  ctx.lineTo(headingEnd.x, headingEnd.y);
  ctx.stroke();
  ctx.setLineDash([]);

  const triAngle = Math.atan2(headingEnd.y - projected.y, headingEnd.x - projected.x);
  ctx.fillStyle = '#ffffff';
  ctx.beginPath();
  ctx.moveTo(headingEnd.x, headingEnd.y);
  ctx.lineTo(headingEnd.x - 8 * Math.cos(triAngle - 0.4), headingEnd.y - 8 * Math.sin(triAngle - 0.4));
  ctx.lineTo(headingEnd.x - 8 * Math.cos(triAngle + 0.4), headingEnd.y - 8 * Math.sin(triAngle + 0.4));
  ctx.closePath();
  ctx.fill();

  // Вектор тяги (Thrust vector)
  if (shuttleThrust > 0) {
    const tv = obj.thrust_vector;
    const tx = Array.isArray(tv) ? tv[0] : 0;
    const ty = Array.isArray(tv) ? tv[1] : 0;
    const tz = Array.isArray(tv) ? tv[2] : 0;
    const thrustMag = Math.sqrt(tx * tx + ty * ty + tz * tz);
    if (thrustMag > 0.001) {
      const thrustScale = 25;
      const thrustEnd = projectPoint(worldX + tx * thrustScale, worldY + ty * thrustScale, worldZ + tz * thrustScale);
      ctx.strokeStyle = '#ffff00';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(projected.x, projected.y);
      ctx.lineTo(thrustEnd.x, thrustEnd.y);
      ctx.stroke();
      drawArrowHead(ctx, projected.x, projected.y, thrustEnd.x, thrustEnd.y, '#ffff00');
    }
  }
}

/**
 * Отрисовка текстовых подписей (имя, высота)
 */
function drawObjectLabels(ctx, item, isDocked, r) {
  const { obj, projected, worldZ, color, isOurShuttle } = item;
  const altitude = worldZ;

  if (isOurShuttle) {
    const altLabel = `Z:${altitude >= 0 ? '+' : ''}${altitude.toFixed(0)}`;
    ctx.fillStyle = '#ff88ff';
    ctx.font = `${Math.min(10 * projected.scale, 11)}px monospace`;
    ctx.textAlign = 'left';
    ctx.globalAlpha = 0.85;
    const labelOffset = -(r + 8);
    ctx.fillText(altLabel, projected.x + labelOffset, projected.y + 3);
    ctx.globalAlpha = 1;
  }

  if (!(isDocked && isOurShuttle)) {
    ctx.fillStyle = color;
    ctx.font = `${Math.min(12 * projected.scale, 13)}px sans-serif`;
    ctx.textAlign = 'left';
    ctx.fillText(obj.name || 'Unknown', projected.x + r + 4, projected.y + 4);
  }
}

/**
 * Главный диспетчер отрисовки объекта
 */
export function renderMapObject(ctx, item, props, projectPoint) {
  const { obj, projected, isOurShuttle } = item;
  const r = Math.max(2, (obj.radius || 5) * projected.scale);

  drawHistoryTrail(ctx, item, projectPoint);

  switch (obj.render_mode) {
    case 'station':
      drawStation(ctx, item, r);
      break;
    case 'planet':
      drawPlanet(ctx, item, r);
      break;
    case 'star':
    case 'sun':
      drawStar(ctx, item, r);
      break;
    case 'shuttle':
      if (isOurShuttle) {
        drawShuttle(ctx, item, r, props.shuttleHeading, props.shuttleThrust);
      } else {
        drawGenericObject(ctx, item, r);
      }
      break;
    default:
      drawGenericObject(ctx, item, r);
      break;
  }

  if (isOurShuttle) {
    drawShuttleVectors(ctx, item, props, projectPoint);
  }

  drawObjectLabels(ctx, item, props.isDocked, r);
}
