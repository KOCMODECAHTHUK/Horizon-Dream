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
    ctx.globalAlpha = 0.15;
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
  if (!isOurShuttle || !obj.position_history || obj.position_history.length < 3) return;

  ctx.strokeStyle = '#a4eea4';
  ctx.lineWidth = 1.5;
  ctx.globalAlpha = 0.4;
  ctx.beginPath();

  const history = obj.position_history;
  // position_history is a flat list: [x1, y1, z1, x2, y2, z2, ...]
  for (let i = 0; i < history.length; i += 3) {
    const hx = history[i] || 0;
    const hy = history[i + 1] || 0;
    const hz = history[i + 2] || 0;
    const hProj = projectPoint(hx, hy, hz);
    if (i === 0) ctx.moveTo(hProj.x, hProj.y);
    else ctx.lineTo(hProj.x, hProj.y);
  }
  ctx.stroke();
  ctx.globalAlpha = 1;
}

/**
 * Отрисовка станции (3D-цилиндр из полигонов)
 */
function drawStation(ctx, item, props, projectPoint) {
  const { obj, ground, color, worldX, worldY, worldZ } = item;
  const stationRadius = obj.radius / 2 || 10;
  const stationHeight = stationRadius * 2;
  const dockRange = obj.docking_range || 30;
  const dockProj = projectPoint(worldX + dockRange, worldY, 0);
  const dockRadius2D = Math.hypot(dockProj.x - ground.x, dockProj.y - ground.y);

  ctx.strokeStyle = '#88aaff';
  ctx.lineWidth = 1;
  ctx.globalAlpha = 0.3;
  ctx.setLineDash([5, 5]);
  ctx.beginPath();
  ctx.arc(ground.x, ground.y, dockRadius2D, 0, Math.PI * 2);
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.globalAlpha = 1;

  // 2. Геометрия цилиндра (8 граней)
  const segments = 8;
  const topZ = worldZ + stationHeight / 2;
  const botZ = worldZ - stationHeight / 2;
  const topPts = [];
  const botPts = [];
  const walls = [];
  for (let i = 0; i < segments; i++) {
    const a = (i / segments) * Math.PI * 2;
    const x = worldX + Math.cos(a) * stationRadius;
    const y = worldY + Math.sin(a) * stationRadius;
    const tP = projectPoint(x, y, topZ);
    const bP = projectPoint(x, y, botZ);
    topPts.push(tP);
    botPts.push(bP);
  }

  // Формируем 4-угольники (грани) и считаем их среднюю глубину
  for (let i = 0; i < segments; i++) {
    const ni = (i + 1) % segments;
    const p1 = topPts[i], p2 = topPts[ni], p3 = botPts[ni], p4 = botPts[i];
    const avgDepth = (p1.depth + p2.depth + p3.depth + p4.depth) / 4;
    walls.push({ p1, p2, p3, p4, depth: avgDepth, angle: (i + 0.5) * (Math.PI * 2 / segments) });
  }
  // Сортируем стенки от дальних к ближним (Painter's algorithm)
  walls.sort((a, b) => b.depth - a.depth);

  // 3. Определяем, какая крышка ближе к камере
  const topCenter = projectPoint(worldX, worldY, topZ);
  const botCenter = projectPoint(worldX, worldY, botZ);
  const topIsFront = topCenter.depth < botCenter.depth;

  const backPts = topIsFront ? botPts : topPts;
  const frontPts = topIsFront ? topPts : botPts;
  const frontZ = topIsFront ? topZ : botZ;

  // 4. Рисуем заднюю крышку (темная)
  ctx.fillStyle = darkenColor(color, 60);
  ctx.beginPath();
  ctx.moveTo(backPts[0].x, backPts[0].y);
  for (let i = 1; i < segments; i++) ctx.lineTo(backPts[i].x, backPts[i].y);
  ctx.closePath();
  ctx.fill();

  // 5. Рисуем стенки цилиндра
  for (const w of walls) {
    // Симулируем свет
    const lightFactor = Math.cos(w.angle - Math.PI);
    let shade;
    if (lightFactor > 0) {
      shade = lightenColor(color, lightFactor * 40);
    } else {
      shade = darkenColor(color, Math.abs(lightFactor) * 50);
    }

    ctx.fillStyle = shade;
    ctx.beginPath();
    ctx.moveTo(w.p1.x, w.p1.y);
    ctx.lineTo(w.p2.x, w.p2.y);
    ctx.lineTo(w.p3.x, w.p3.y);
    ctx.lineTo(w.p4.x, w.p4.y);
    ctx.closePath();
    ctx.fill();

    // Разделительная линия между панелями
    ctx.strokeStyle = 'rgba(0, 0, 0, 0.3)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(w.p1.x, w.p1.y);
    ctx.lineTo(w.p4.x, w.p4.y);
    ctx.stroke();
  }

  // 6. Рисуем переднюю крышку
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(frontPts[0].x, frontPts[0].y);
  for (let i = 1; i < segments; i++) ctx.lineTo(frontPts[i].x, frontPts[i].y);
  ctx.closePath();
  ctx.fill();

  // Контур передней крышки
  ctx.strokeStyle = darkenColor(color, 30);
  ctx.lineWidth = 1.5;
  ctx.stroke();

  // 7. Рисуем шлюз (3D-круг на передней крышке)
  // Внешнее кольцо шлюза
  const innerR1 = stationRadius * 0.5;
  const innerPts1 = [];
  for (let i = 0; i < segments; i++) {
    const a = (i / segments) * Math.PI * 2;
    const x = worldX + Math.cos(a) * innerR1;
    const y = worldY + Math.sin(a) * innerR1;
    innerPts1.push(projectPoint(x, y, frontZ));
  }
  ctx.strokeStyle = darkenColor(color, 50);
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(innerPts1[0].x, innerPts1[0].y);
  for (let i = 1; i < segments; i++) ctx.lineTo(innerPts1[i].x, innerPts1[i].y);
  ctx.closePath();
  ctx.stroke();

  // Внутренняя часть шлюза (темное отверстие)
  const innerR2 = stationRadius * 0.2;
  const innerPts2 = [];
  for (let i = 0; i < segments; i++) {
    const a = (i / segments) * Math.PI * 2;
    const x = worldX + Math.cos(a) * innerR2;
    const y = worldY + Math.sin(a) * innerR2;
    innerPts2.push(projectPoint(x, y, frontZ));
  }
  ctx.fillStyle = darkenColor(color, 70);
  ctx.beginPath();
  ctx.moveTo(innerPts2[0].x, innerPts2[0].y);
  for (let i = 1; i < segments; i++) ctx.lineTo(innerPts2[i].x, innerPts2[i].y);
  ctx.closePath();
  ctx.fill();

  // 8. Мигающие сигнальные огни на краях цилиндра
  const blink = (Math.sin(Date.now() / 1000) + 1) / 2;
  const light1 = topIsFront ? topPts[0] : botPts[0];
  const light2 = topIsFront ? topPts[segments / 2] : botPts[segments / 2];

  ctx.fillStyle = `rgba(255, 50, 50, ${blink})`;
  ctx.beginPath();
  ctx.arc(light1.x, light1.y, 2.5, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = `rgba(50, 150, 255, ${1 - blink})`;
  ctx.beginPath();
  ctx.arc(light2.x, light2.y, 2.5, 0, Math.PI * 2);
  ctx.fill();
}

/**
 * Отрисовка планеты (3D-сфера с освещением)
 */
// Кэш для вершин сферы, чтобы не генерировать их каждый кадр
let planetSphereCache = null;

function getSphereMesh(segments = 10, rings = 5) {
  if (planetSphereCache) return planetSphereCache;

  const verts = [];
  const faces = [];

  for (let y = 0; y <= rings; y++) {
    const v = y / rings;
    const phi = v * Math.PI;
    for (let x = 0; x <= segments; x++) {
      const u = x / segments;
      const theta = u * Math.PI * 2;
      verts.push({
        x: Math.cos(theta) * Math.sin(phi),
        y: Math.sin(theta) * Math.sin(phi),
        z: Math.cos(phi)
      });
    }
  }

  for (let y = 0; y < rings; y++) {
    for (let x = 0; x < segments; x++) {
      const i = y * (segments + 1) + x;
      const a = i;
      const b = i + 1;
      const c = i + segments + 1;
      const d = i + segments + 2;
      faces.push([a, b, d]); // Треугольник 1
      faces.push([a, d, c]); // Треугольник 2
    }
  }

  planetSphereCache = { verts, faces };
  return planetSphereCache;
}

/**
 * Отрисовка планеты (Полноценный 3D-меш сферы)
 */
function drawPlanet(ctx, item, r, props, projectPoint) {
  const { projected, ground, color, obj, worldX, worldY, worldZ } = item;
  const worldRadius = obj.radius || 20;
  const planetRadius2D = Math.max(8, worldRadius * projected.scale);

  // 1. Атмосферный ореол (Halo) - оставляем 2D, это дешевле и выглядит отлично
  ctx.globalAlpha = 0.3;
  const glowGrad = ctx.createRadialGradient(ground.x, ground.y, planetRadius2D * 0.9, ground.x, ground.y, planetRadius2D * 1.4);
  glowGrad.addColorStop(0, color);
  glowGrad.addColorStop(1, 'transparent');
  ctx.fillStyle = glowGrad;
  ctx.beginPath();
  ctx.arc(projected.x, projected.y, planetRadius2D * 1.4, 0, Math.PI * 2);
  ctx.fill();
  ctx.globalAlpha = 1;

  // 2. Получаем 3D-меш сферы
  const { verts, faces } = getSphereMesh(12, 6); // 12 сегментов, 6 колец = 144 полигона

  // 3. Проецируем все вершины в 2D
  const projData = verts.map(v => {
    const wx = worldX + v.x * worldRadius;
    const wy = worldY + v.y * worldRadius;
    const wz = worldZ + v.z * worldRadius;
    return {
      proj: projectPoint(wx, wy, wz),
      local: v
    };
  });

  // 4. Вычисляем 3D вектор света (от планеты к звезде)
  let lightDir = { x: -0.5, y: -0.5, z: 0.8 };
  const mapObjects = props.map_objects || [];
  const star = mapObjects.find(o => o.render_mode === 'star' || o.render_mode === 'sun');
  if (star) {
    const dx = (star.position_x ?? 0) - worldX;
    const dy = (star.position_y ?? 0) - worldY;
    const dz = (star.position_z ?? 0) - worldZ;
    const len = Math.hypot(dx, dy, dz);
    if (len > 0) lightDir = { x: dx / len, y: dy / len, z: dz / len };
  }

  const renderFaces = [];

  // 5. Обрабатываем грани
  for (const face of faces) {
    const p0 = projData[face[0]];
    const p1 = projData[face[1]];
    const p2 = projData[face[2]];

    const avgDepth = (p0.proj.depth + p1.proj.depth + p2.proj.depth) / 3;

    // Нормаль грани (усредняем локальные координаты вершин)
    const nx = (p0.local.x + p1.local.x + p2.local.x) / 3;
    const ny = (p0.local.y + p1.local.y + p2.local.y) / 3;
    const nz = (p0.local.z + p1.local.z + p2.local.z) / 3;
    const nLen = Math.hypot(nx, ny, nz);
    const normal = { x: nx / nLen, y: ny / nLen, z: nz / nLen };

    // Уровень освещенности (0.1 - глубокая ночь, 1.0 - яркий день)
    let lightFactor = normal.x * lightDir.x + normal.y * lightDir.y + normal.z * lightDir.z;
    lightFactor = Math.max(0.1, lightFactor);

    let faceColor;
    if (lightFactor > 0.5) {
      faceColor = lightenColor(color, (lightFactor - 0.5) * 80);
    } else {
      faceColor = darkenColor(color, (0.5 - lightFactor) * 90);
    }

    renderFaces.push({
      projVerts: [p0.proj, p1.proj, p2.proj],
      faceColor,
      avgDepth
    });
  }

  // 6. Сортировка от дальней к ближней
  renderFaces.sort((a, b) => b.avgDepth - a.avgDepth);

  // 7. Отрисовка полигонов
  for (const rf of renderFaces) {
    ctx.fillStyle = rf.faceColor;
    // Делаем цвет линий таким же, как цвет заливки.
    // Это убирает "сетку" и маскирует микро-зазоры между треугольниками (anti-aliasing seams).
    ctx.strokeStyle = rf.faceColor;
    ctx.lineWidth = 1;

    ctx.beginPath();
    ctx.moveTo(rf.projVerts[0].x, rf.projVerts[0].y);
    ctx.lineTo(rf.projVerts[1].x, rf.projVerts[1].y);
    ctx.lineTo(rf.projVerts[2].x, rf.projVerts[2].y);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
  }

  // 8. Легкое затемнение краев (Лимб) для объема
  ctx.save();
  ctx.beginPath();
  ctx.arc(projected.x, projected.y, planetRadius2D, 0, Math.PI * 2);
  ctx.clip();
  const limbGrad = ctx.createRadialGradient(projected.x, projected.y, planetRadius2D * 0.6, projected.x, projected.y, planetRadius2D);
  limbGrad.addColorStop(0, 'rgba(0,0,0,0)');
  limbGrad.addColorStop(1, 'rgba(0,0,0,0.6)');
  ctx.fillStyle = limbGrad;
  ctx.fillRect(projected.x - planetRadius2D, projected.y - planetRadius2D, planetRadius2D * 2, planetRadius2D * 2);
  ctx.restore();
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
 * Отрисовка нашего шаттла (Полноценный 3D-меш)
 */
function drawShuttle(ctx, item, r, props, projectPoint) {
  const { projected, color, worldX, worldY, worldZ, obj } = item;
  const { shuttleHeading = 0, shuttleHeadingPitch = 0, shuttleThrust = 0 } = props;

  const scale = (obj.radius / 2 || 5);

  // 1. Поиск источника света (звезды)
  let lightDir = { x: -0.5, y: -0.5, z: 0.8 };
  const mapObjects = props.map_objects || [];
  const star = mapObjects.find(o => o.render_mode === 'star' || o.render_mode === 'sun');
  if (star) {
    const dx = (star.position_x ?? 0) - worldX;
    const dy = (star.position_y ?? 0) - worldY;
    const dz = (star.position_z ?? 0) - worldZ;
    const len = Math.hypot(dx, dy, dz);
    if (len > 0) lightDir = { x: dx / len, y: dy / len, z: dz / len };
  }

  // 2. Математика вращения (0 = Восток (+X), 90 = Север (+Y))
  const yawRad = shuttleHeading * DEG2RAD;
  const pitchRad = shuttleHeadingPitch * DEG2RAD;

  const transformPoint = (lx, ly, lz) => {
    let x1 = lx * Math.cos(pitchRad) - lz * Math.sin(pitchRad);
    let z1 = lx * Math.sin(pitchRad) + lz * Math.cos(pitchRad);
    let y1 = ly;
    let x2 = x1 * Math.cos(yawRad) - y1 * Math.sin(yawRad);
    let y2 = x1 * Math.sin(yawRad) + y1 * Math.cos(yawRad);
    let z2 = z1;
    return {
      x: worldX + x2 * scale,
      y: worldY + y2 * scale,
      z: worldZ + z2 * scale
    };
  };

  // 3. Вершины 3D-модели "Дротик" (Нос = +X, Правое крыло = -Y, Верх = +Z)
  const v = {
    nose:       transformPoint(2.5, 0, 0),
    tailTop:    transformPoint(-1.5, 0, 0.6),
    tailBot:    transformPoint(-1.5, 0, -0.6),
    rightWing:  transformPoint(-0.5, -1.5, 0),
    leftWing:   transformPoint(-0.5, 1.5, 0),
  };

  // 4. Грани корабля (Строго треугольники)
  const faces = [
    { verts: [v.nose, v.rightWing, v.tailTop] }, // Правый верх
    { verts: [v.nose, v.tailTop, v.leftWing] },  // Левый верх
    { verts: [v.nose, v.tailBot, v.rightWing] }, // Правый низ
    { verts: [v.nose, v.leftWing, v.tailBot] },  // Левый низ
    { verts: [v.rightWing, v.tailBot, v.tailTop] }, // Правый борт
    { verts: [v.leftWing, v.tailTop, v.tailBot] }   // Левый борт
  ];

  const renderFaces = [];

  for (const face of faces) {
    const w0 = face.verts[0], w1 = face.verts[1], w2 = face.verts[2];
    const cx = (w0.x + w1.x + w2.x) / 3;
    const cy = (w0.y + w1.y + w2.y) / 3;
    const cz = (w0.z + w1.z + w2.z) / 3;
    const e1 = { x: w1.x - w0.x, y: w1.y - w0.y, z: w1.z - w0.z };
    const e2 = { x: w2.x - w0.x, y: w2.y - w0.y, z: w2.z - w0.z };
    let normal = {
      x: e1.y * e2.z - e1.z * e2.y,
      y: e1.z * e2.x - e1.x * e2.z,
      z: e1.x * e2.y - e1.y * e2.x
    };
    const nLen = Math.hypot(normal.x, normal.y, normal.z);
    if (nLen === 0) continue;
    normal.x /= nLen; normal.y /= nLen; normal.z /= nLen;
    const toCenter = { x: worldX - cx, y: worldY - cy, z: worldZ - cz };
    if (normal.x * toCenter.x + normal.y * toCenter.y + normal.z * toCenter.z > 0) {
      normal.x = -normal.x; normal.y = -normal.y; normal.z = -normal.z;
    }
    const proj0 = projectPoint(w0.x, w0.y, w0.z);
    const proj1 = projectPoint(w1.x, w1.y, w1.z);
    const proj2 = projectPoint(w2.x, w2.y, w2.z);
    const avgDepth = (proj0.depth + proj1.depth + proj2.depth) / 3;
    let lightFactor = normal.x * lightDir.x + normal.y * lightDir.y + normal.z * lightDir.z;
    lightFactor = Math.max(0.2, lightFactor);
    let faceColor = lightFactor > 0.5
      ? lightenColor(color, (lightFactor - 0.5) * 80)
      : darkenColor(color, (0.5 - lightFactor) * 80);
    renderFaces.push({
      projVerts: [proj0, proj1, proj2],
      faceColor,
      avgDepth
    });
  }

  // 5. Сортировка от дальней к ближней (Без отсечения, просто закрашиваем)
  renderFaces.sort((a, b) => b.avgDepth - a.avgDepth);

  // 6. Отрисовка
  for (const rf of renderFaces) {
    ctx.fillStyle = rf.faceColor;
    ctx.strokeStyle = darkenColor(rf.faceColor, 30);
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(rf.projVerts[0].x, rf.projVerts[0].y);
    ctx.lineTo(rf.projVerts[1].x, rf.projVerts[1].y);
    ctx.lineTo(rf.projVerts[2].x, rf.projVerts[2].y);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
  }

  // 7. 3D-Пламя двигателей
  if (shuttleThrust > 0) {
    const flicker = 0.6 + 0.4 * Math.sin(Date.now() / 100);
    const thrustLen = (shuttleThrust / 100) * 3 * flicker;

    const engineL = transformPoint(-1.5, 0.3, 0);
    const engineR = transformPoint(-1.5, -0.3, 0);
    const endL = transformPoint(-1.5 - thrustLen, 0.3, 0);
    const endR = transformPoint(-1.5 - thrustLen, -0.3, 0);
    const endC = transformPoint(-1.5 - thrustLen * 1.2, 0, 0);

    const pEL = projectPoint(engineL.x, engineL.y, engineL.z);
    const pER = projectPoint(engineR.x, engineR.y, engineR.z);
    const pEndL = projectPoint(endL.x, endL.y, endL.z);
    const pEndR = projectPoint(endR.x, endR.y, endR.z);
    const pEndC = projectPoint(endC.x, endC.y, endC.z);

    ctx.globalAlpha = 0.7 * flicker;
    ctx.fillStyle = '#ff5500';
    ctx.beginPath();
    ctx.moveTo(pEL.x, pEL.y);
    ctx.lineTo(pEndC.x, pEndC.y);
    ctx.lineTo(pER.x, pER.y);
    ctx.closePath();
    ctx.fill();

    ctx.globalAlpha = 0.9 * flicker;
    ctx.fillStyle = '#ffff00';
    ctx.beginPath();
    ctx.moveTo(pEL.x, pEL.y);
    ctx.lineTo(pEndL.x, pEndL.y);
    ctx.lineTo(pER.x, pER.y);
    ctx.lineTo(pEndR.x, pEndR.y);
    ctx.closePath();
    ctx.fill();
    ctx.globalAlpha = 1;
  }
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

/*
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
*/

  // Вектор тяги (Thrust vector)
  if (shuttleThrust > 0) {
    const tx = obj.thrust_x || 0;
    const ty = obj.thrust_y || 0;
    const tz = obj.thrust_z || 0;
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
 * Проверка пересечения прямоугольников (для текста)
 */
function checkLabelCollision(bbox, drawnLabels) {
  for (const l of drawnLabels) {
    if (bbox.x < l.x + l.w && bbox.x + bbox.w > l.x && bbox.y < l.y + l.h && bbox.y + bbox.h > l.y) {
      return true;
    }
  }
  return false;
}

/**
 * Отрисовка текстовых подписей (имя, высота)
 */
function drawObjectLabels(ctx, item, isDocked, r, drawnLabels) {
  const { obj, projected, worldZ, color, isOurShuttle } = item;
  const altitude = worldZ;

  if (isOurShuttle) {
    const altLabel = ``;
    ctx.fillStyle = '#ff88ff';
    ctx.font = `${Math.min(10 * projected.scale, 11)}px monospace`;
    ctx.textAlign = 'left';
    ctx.globalAlpha = 0.85;
    const labelOffset = -(r + 8);

    const textWidth = ctx.measureText(altLabel).width;
    const bbox = { x: projected.x + labelOffset, y: projected.y - 8, w: textWidth, h: 12 };

    if (!checkLabelCollision(bbox, drawnLabels)) {
      ctx.fillText(altLabel, projected.x + labelOffset, projected.y + 3);
      drawnLabels.push(bbox);
    }
    ctx.globalAlpha = 1;
  }

  if (!(isDocked && isOurShuttle)) {
    ctx.fillStyle = color;
    ctx.font = `${Math.min(12 * projected.scale, 13)}px sans-serif`;
    ctx.textAlign = 'left';
    const labelText = obj.name || 'Unknown';
    const textWidth = ctx.measureText(labelText).width;
    const bbox = { x: projected.x + r + 4, y: projected.y - 8, w: textWidth, h: 12 };
    if (!checkLabelCollision(bbox, drawnLabels)) {
      ctx.fillText(labelText, projected.x + r + 4, projected.y + 4);
      drawnLabels.push(bbox);
    }
  }
}

/**
 * Главный диспетчер отрисовки объекта
 */
export function renderMapObject(ctx, item, props, projectPoint, drawnLabels) {
  const { obj, projected, isOurShuttle } = item;
  const r = Math.max(2, (obj.radius || 5) * projected.scale);

  if (isOurShuttle && props.isDocked) {
    return;
  }

  drawHistoryTrail(ctx, item, projectPoint);

  switch (obj.render_mode) {
    case 'station':
      drawStation(ctx, item, props, projectPoint);
      break;
    case 'planet':
      drawPlanet(ctx, item, r, props, projectPoint);
      break;
    case 'star':
    case 'sun':
      drawStar(ctx, item, r);
      break;
    case 'shuttle':
      if (isOurShuttle) {
        drawShuttle(ctx, item, r, props, projectPoint);
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

  drawObjectLabels(ctx, item, props.isDocked, r, drawnLabels);
}
