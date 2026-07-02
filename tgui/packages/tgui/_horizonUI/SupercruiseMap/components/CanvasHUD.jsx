// CanvasHUD.jsx
import { DEG2RAD } from './MapUtils';

/**
 * Отрисовка 3D стрелки в виде пирамиды (для компаса)
 */
function drawArrowAsPyramid(ctx, projectWorld, tipDir, color, baseSize = 0.06, height = 0.2, baseAtCenter = false) {
  const tipPoint = baseAtCenter
    ? { x: tipDir.x * height, y: tipDir.y * height, z: tipDir.z * height }
    : { x: tipDir.x * (1 + height), y: tipDir.y * (1 + height), z: tipDir.z * (1 + height) };

  let perp1;
  perp1 = Math.abs(tipDir.x) < 0.9
    ? { x: 0, y: -tipDir.z, z: tipDir.y }
    : { x: -tipDir.z, y: 0, z: tipDir.x };

  const len1 = Math.hypot(perp1.x, perp1.y, perp1.z);
  perp1 = { x: perp1.x / len1, y: perp1.y / len1, z: perp1.z / len1 };
  const perp2 = {
    x: tipDir.y * perp1.z - tipDir.z * perp1.y,
    y: tipDir.z * perp1.x - tipDir.x * perp1.z,
    z: tipDir.x * perp1.y - tipDir.y * perp1.x
  };

  const baseSides = 3;
  const basePoints = [];
  for (let i = 0; i < baseSides; i++) {
    const angle = (i / baseSides) * Math.PI * 2;
    const cosA = Math.cos(angle) * baseSize;
    const sinA = Math.sin(angle) * baseSize;
    const baseX = perp1.x * cosA + perp2.x * sinA;
    const baseY = perp1.y * cosA + perp2.y * sinA;
    const baseZ = perp1.z * cosA + perp2.z * sinA;
    const pt = baseAtCenter ? { x: baseX, y: baseY, z: baseZ } : { x: tipDir.x + baseX, y: tipDir.y + baseY, z: tipDir.z + baseZ };
    basePoints.push(projectWorld(pt));
  }

  const tipProj = projectWorld(tipPoint);
  ctx.lineWidth = 1;

  for (let i = 0; i < baseSides; i++) {
    const next = (i + 1) % baseSides;

    ctx.fillStyle = color;
    ctx.globalAlpha = 0.7;
    ctx.beginPath();
    ctx.moveTo(tipProj.x, tipProj.y);
    ctx.lineTo(basePoints[i].x, basePoints[i].y);
    ctx.lineTo(basePoints[next].x, basePoints[next].y);
    ctx.closePath();
    ctx.fill();

    ctx.strokeStyle = color;
    ctx.globalAlpha = 0.9;
    ctx.stroke();
  }
  ctx.globalAlpha = 1;
}

/**
 * Отрисовка диска (окружности) на сфере компаса
 */
function drawDisk(ctx, projectWorld, strokeColor, pointFn) {
  ctx.strokeStyle = strokeColor;
  ctx.lineWidth = 1;
  ctx.beginPath();

  const firstPt = projectWorld(pointFn(0, 1));
  ctx.moveTo(firstPt.x, firstPt.y);

  for (let a = 5; a <= 360; a += 5) {
    const pt = projectWorld(pointFn(a * DEG2RAD, 1));
    ctx.lineTo(pt.x, pt.y);
  }
  ctx.closePath();
  ctx.stroke();
  ctx.setLineDash([]);
}

/**
 * Отрисовка подписей (0°, 90° и т.д.) на экваторе компаса
 */
function drawDiskGraduations(ctx, projectWorld, cx, cy, pointFn, labels) {
  const labelRadius = 1.4;
  const normalize2 = (v) => {
    const len = Math.hypot(v.x, v.y);
    return len > 0 ? { x: v.x / len, y: v.y / len } : { x: 1, y: 0 };
  };

  ctx.font = '8px sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = 'rgba(200, 220, 255, 0.9)';

  for (let i = 0; i < 4; i++) {
    const angleRad = i * 90 * DEG2RAD;
    const labelPos = projectWorld(pointFn(angleRad, labelRadius));
    const screenTangent = projectWorld(pointFn(angleRad + 0.05, labelRadius));
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

/**
 * Отрисовка сегментов экватора
 */
function drawEquatorSegments(ctx, projectWorld, pointFn) {
  const arcHalfAngle = 10;
  const offset = 0.12;
  ctx.lineWidth = 1;
  ctx.lineCap = 'round';

  for (const centerDeg of [0, 90, 180, 270]) {
    const pointsUpper = [];
    const pointsLower = [];
    const steps = 6;

    for (let s = -steps; s <= steps; s++) {
      const angleRad = (centerDeg + (s / steps) * arcHalfAngle) * DEG2RAD;
      const base = pointFn(angleRad, 1);
      pointsUpper.push(projectWorld({ x: base.x, y: base.y, z: base.z + offset }));
      pointsLower.push(projectWorld({ x: base.x, y: base.y, z: base.z - offset }));
    }

    ctx.strokeStyle = 'rgba(200, 220, 255, 0.8)';
    ctx.beginPath();
    pointsUpper.forEach((pt, idx) => idx === 0 ? ctx.moveTo(pt.x, pt.y) : ctx.lineTo(pt.x, pt.y));
    ctx.stroke();

    ctx.strokeStyle = 'rgba(140, 160, 200, 0.5)';
    ctx.beginPath();
    pointsLower.forEach((pt, idx) => idx === 0 ? ctx.moveTo(pt.x, pt.y) : ctx.lineTo(pt.x, pt.y));
    ctx.stroke();
  }
}

/**
 * Отрисовка 3D компаса и индикаторов скорости/тяги
 */
function drawSphereCompass(ctx, cx, cy, radius, cameraYaw, cameraPitch, shipHeading, shipHeadingPitch, shuttleThrust, shuttleAngle, velMag, velX, velY, velZ, maxSpeed) {
  const cosY = Math.cos(cameraYaw * DEG2RAD);
  const sinY = Math.sin(cameraYaw * DEG2RAD);
  const cosP = Math.cos(cameraPitch * DEG2RAD);
  const sinP = Math.sin(cameraPitch * DEG2RAD);
  const sphereScale = radius * 0.85;

  const rotateToCamera = ({ x, y, z }) => {
    const x1 = x * cosY - y * sinY;
    const y1 = x * sinY + y * cosY;
    return { x: x1, y: y1 * cosP - z * sinP, z: y1 * sinP + z * cosP };
  };

  const project = ({ x, y, z }) => ({ x: cx + x * sphereScale, y: cy - z * sphereScale, depth: y });
  const projectWorld = (point) => project(rotateToCamera(point));
  const normalize = (v) => {
    const len = Math.hypot(v.x, v.y, v.z);
    return len > 0 ? { x: v.x / len, y: v.y / len, z: v.z / len } : { x: 0, y: 0, z: 0 };
  };

  // Сфера компаса
  ctx.fillStyle = 'rgba(50, 100, 255, 0.2)';
  ctx.beginPath();
  ctx.arc(cx, cy, sphereScale, 0, Math.PI * 2);
  ctx.fill();

  const diskStrokeColor = 'rgba(150, 200, 255, 0.6)';
  const diskLineColor = 'rgba(150, 200, 255, 0.08)';

  drawDisk(ctx, projectWorld, diskStrokeColor, (angle, mult = 1) => ({ x: Math.cos(angle) * mult, y: Math.sin(angle) * mult, z: 0 }));
  drawDisk(ctx, projectWorld, diskLineColor, (angle, mult = 1) => ({ x: Math.cos(angle) * mult, y: 0, z: Math.sin(angle) * mult }));
  drawDisk(ctx, projectWorld, diskLineColor, (angle, mult = 1) => ({ x: 0, y: Math.cos(angle) * mult, z: Math.sin(angle) * mult }));
  drawEquatorSegments(ctx, projectWorld, (angle, mult = 1) => ({ x: Math.cos(angle) * mult, y: Math.sin(angle) * mult, z: 0 }));
  drawDiskGraduations(ctx, projectWorld, cx, cy, (angle, mult = 1) => ({ x: Math.cos(angle) * mult, y: Math.sin(angle) * mult, z: 0 }), ['0°', '90°', '180°', '270°']);

  // Оси
  ctx.strokeStyle = diskLineColor;
  ctx.lineWidth = 1;
  const drawAxisLine = (p1, p2) => {
    ctx.beginPath();
    ctx.moveTo(p1.x, p1.y);
    ctx.lineTo(p2.x, p2.y);
    ctx.stroke();
  };
  drawAxisLine(projectWorld({ x: -1.15, y: 0, z: 0 }), projectWorld({ x: 1.15, y: 0, z: 0 }));
  drawAxisLine(projectWorld({ x: 0, y: -1.15, z: 0 }), projectWorld({ x: 0, y: 1.15, z: 0 }));

  // Направление корабля
  const headingRad = shipHeading * DEG2RAD;
  const pitchHeadingRad = shipHeadingPitch * DEG2RAD;
  const shipDir = normalize({
    x: Math.cos(pitchHeadingRad) * Math.cos(headingRad),
    y: Math.cos(pitchHeadingRad) * Math.sin(headingRad),
    z: Math.sin(pitchHeadingRad)
  });

  drawArrowAsPyramid(ctx, projectWorld, shipDir, '#00ff80', 0.06, 0.25, true);
  const noseEnd = projectWorld(shipDir);

  ctx.strokeStyle = '#00ff80';
  ctx.globalAlpha = 0.3;
  ctx.setLineDash([4, 3]);
  ctx.beginPath();
  ctx.moveTo(cx, cy);
  ctx.lineTo(noseEnd.x, noseEnd.y);
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.globalAlpha = 1;

  // Вектор скорости
  if (velMag > 0.5) {
    const velDir = normalize({ x: velX, y: velY, z: velZ });
    drawArrowAsPyramid(ctx, projectWorld, velDir, '#00ffff', 0.06, 0.34, false);
  }

  // Вектор тяги
  if (shuttleThrust > 0) {
    const thrustYawRad = shuttleAngle * DEG2RAD;
    const thrDir = normalize({
      x: Math.cos(pitchHeadingRad) * Math.cos(thrustYawRad),
      y: Math.cos(pitchHeadingRad) * Math.sin(thrustYawRad),
      z: Math.sin(pitchHeadingRad)
    });
    const thrEnd = projectWorld(thrDir);

    ctx.strokeStyle = '#ffff00';
    ctx.globalAlpha = 0.5;
    ctx.lineWidth = 2;
    ctx.setLineDash([4, 3]);
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(thrEnd.x, thrEnd.y);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.globalAlpha = 1;
  }

  // === ИНДИКАТОРЫ СКОРОСТИ И ТЯГИ ===
  const barHeight = sphereScale * 1.8;
  const barLength = 28;
  const barTopY = cy - barHeight / 2;
  const barBotY = cy + barHeight / 2;
  const barWidth = 4;

  ctx.lineCap = 'round';
  ctx.lineWidth = barWidth;

  // 1. Левая шкала (Скорость)
  const velX = cx - sphereScale - barLength;
  const velPct = Math.min(100, (velMag / (maxSpeed || 50)) * 100);
  const velFillTop = barBotY - (barHeight) * (velPct / 100);

  // Фон шкалы
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.15)';
  ctx.beginPath();
  ctx.moveTo(velX, barTopY);
  ctx.lineTo(velX, barBotY);
  ctx.stroke();

  // Заполнение шкалы (голубым)
  ctx.strokeStyle = '#00ffff';
  ctx.beginPath();
  ctx.moveTo(velX, barBotY);
  ctx.lineTo(velX, velFillTop);
  ctx.stroke();

  // Маркер (треугольник, указывающий на текущее значение)
  ctx.fillStyle = '#00ffff';
  ctx.beginPath();
  ctx.moveTo(velX - 2, velFillTop);
  ctx.lineTo(velX - 8, velFillTop - 4);
  ctx.lineTo(velX - 8, velFillTop + 4);
  ctx.closePath();
  ctx.fill();

  // Текст (Значение и единицы измерения)
  ctx.font = 'bold 10px monospace';
  ctx.textAlign = 'right';
  ctx.fillText(`${Math.round(velMag * 10)}`, velX - 12, barTopY + 4); // Умножаем на 10 для эстетики км/ч
  ctx.font = '8px monospace';
  ctx.fillStyle = 'rgba(0, 255, 255, 0.7)';
  ctx.fillText('км/ч', velX - 12, barTopY + 14);

  // 2. Правая шкала (Ускорение/Тяга)
  const thrX = cx + sphereScale + barLength;
  const thrPct = Math.min(100, shuttleThrust);
  const thrFillTop = barBotY - (barHeight) * (thrPct / 100);

  // Фон шкалы
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.15)';
  ctx.beginPath();
  ctx.moveTo(thrX, barTopY);
  ctx.lineTo(thrX, barBotY);
  ctx.stroke();

  // Заполнение шкалы (желтым)
  ctx.strokeStyle = '#ffff00';
  ctx.beginPath();
  ctx.moveTo(thrX, barBotY);
  ctx.lineTo(thrX, thrFillTop);
  ctx.stroke();

  // Маркер (треугольник, указывающий на текущее значение)
  ctx.fillStyle = '#ffff00';
  ctx.beginPath();
  ctx.moveTo(thrX + 2, thrFillTop);
  ctx.lineTo(thrX + 8, thrFillTop - 4);
  ctx.lineTo(thrX + 8, thrFillTop + 4);
  ctx.closePath();
  ctx.fill();

  // Текст (Значение и единицы измерения)
  ctx.font = 'bold 10px monospace';
  ctx.textAlign = 'left';
  ctx.fillStyle = '#ffff00';
  ctx.fillText(`${Math.round(thrPct)}`, thrX + 12, barTopY + 4);
  ctx.font = '8px monospace';
  ctx.fillStyle = 'rgba(255, 255, 0, 0.7)';
  ctx.fillText('тяга %', thrX + 12, barTopY + 14);

  ctx.fillStyle = '#aaa';
  ctx.font = '9px monospace';
  ctx.textAlign = 'center';
  ctx.fillText(`PIT: ${Math.round(shipHeadingPitch)}°`, cx, cy + radius + 14);
}

/**
 * Вспомогательная функция для отрисовки панелей HUD
 */
function drawPanel(ctx, x, y, w, h) {
  ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = '#333';
  ctx.lineWidth = 1;
  ctx.strokeRect(x, y, w, h);
}

/**
 * Главная функция отрисовки HUD
 */
export function drawHUD(ctx, props, canvasWidth, canvasHeight) {
  const {
    shuttleAngle = 0, shuttleThrust = 0, shuttleHeading = 0, shuttleHeadingPitch = 0,
    shuttleVelX = 0, shuttleVelY = 0, shuttleVelZ = 0,
    shuttleMaxSpeed = 50,
    cameraYaw = 45, cameraPitch = 30, isDocked = false, autopilotEnabled = false, hasPendingTarget = false,
    fuelLevel = 100, fuelMax = 100,
    targetDistance = null, targetETA = null,
    radarStatus = 'ACTIVE',
  } = props;

  const velMag = Math.hypot(shuttleVelX, shuttleVelY, shuttleVelZ);

  // --- Компас ---
  const compassX = canvasWidth / 2;
  const compassY = canvasHeight - 50;
  const compassRadius = 45;
  drawSphereCompass(ctx, compassX, compassY, compassRadius, cameraYaw, cameraPitch,
    shuttleHeading, shuttleHeadingPitch, shuttleThrust, shuttleAngle, velMag, shuttleVelX, shuttleVelY, shuttleVelZ, shuttleMaxSpeed);

  // --- Левая панель (Топливо / Тяга) ---
  const lx = 10;
  const ly = canvasHeight - 90;
  const pw = 135;
  const ph = 65;
  drawPanel(ctx, lx, ly, pw, ph);

  const fuelPct = fuelMax > 0 ? (fuelLevel / fuelMax) * 100 : 0;
  ctx.font = 'bold 10px monospace';
  ctx.textAlign = 'left';

  ctx.fillStyle = '#ffaa00';
  ctx.fillText(`FUEL: ${Math.round(fuelPct)}%`, lx + 6, ly + 16);
  ctx.fillStyle = '#332200';
  ctx.fillRect(lx + 6, ly + 20, pw - 12, 8);
  ctx.fillStyle = fuelPct > 20 ? '#ffaa00' : '#ff3333';
  ctx.fillRect(lx + 6, ly + 20, (pw - 12) * (fuelPct / 100), 8);

  // --- Правая панель (Цели / Радар) ---
  const rx = canvasWidth - 145;
  const ry = canvasHeight - 90;
  drawPanel(ctx, rx, ry, pw, ph);

  ctx.font = 'bold 10px monospace';
  ctx.textAlign = 'left';

  ctx.fillStyle = targetDistance != null ? '#00ff88' : '#555';
  ctx.fillText(`TGT: ${targetDistance != null ? `${targetDistance.toFixed(0)} km` : '--'}`, rx + 6, ry + 16);

  ctx.fillStyle = targetETA != null ? '#00ff88' : '#555';
  ctx.fillText(`ETA: ${targetETA != null ? targetETA : '--'}`, rx + 6, ry + 32);

  ctx.fillStyle = radarStatus === 'ACTIVE' ? '#44ff44' : '#ff4444';
  ctx.fillText(`RDR: ${radarStatus}`, rx + 6, ry + 48);

  let statusText = '';
  let statusColor = '';
  let statusFont = '';
  let statusY = 20;

  switch (true) {
    case isDocked:
      statusText = 'DOCKED';
      statusColor = 'rgba(200, 0, 0, 0.8)';
      statusFont = 'bold 16px sans-serif';
      statusY = 25;
      break;
    case autopilotEnabled:
      statusText = 'AUTOPILOT';
      statusColor = 'rgba(0, 200, 0, 0.8)';
      statusFont = 'bold 16px sans-serif';
      statusY = 20;
      break;
    case hasPendingTarget:
      statusText = 'COURSE PENDING';
      statusColor = 'rgba(255, 200, 0, 0.9)';
      statusFont = 'bold 14px sans-serif';
      statusY = 20;
      break;
    default:
      break;
  }

  if (statusText) {
    ctx.fillStyle = statusColor;
    ctx.font = statusFont;
    ctx.textAlign = 'center';
    ctx.fillText(statusText, canvasWidth / 2, statusY);
  }
}
