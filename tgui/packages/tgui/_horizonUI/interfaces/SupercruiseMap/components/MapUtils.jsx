export const FPS = 30;
export const DEG2RAD = Math.PI / 180;

// === Цветовые утилиты ===
export function hexToRgb(hex) {
  if (!hex || typeof hex !== 'string') return { r: 128, g: 128, b: 128 };
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result ? {
    r: parseInt(result[1], 16),
    g: parseInt(result[2], 16),
    b: parseInt(result[3], 16)
  } : { r: 128, g: 128, b: 128 };
}

export function rgbToHex(r, g, b) {
  return '#' + [r, g, b].map(x => {
    const hex = Math.round(Math.max(0, Math.min(255, x))).toString(16);
    return hex.length === 1 ? '0' + hex : hex;
  }).join('');
}

export function lightenColor(hex, percent) {
  const rgb = hexToRgb(hex);
  return rgbToHex(
    rgb.r + (255 - rgb.r) * (percent / 100),
    rgb.g + (255 - rgb.g) * (percent / 100),
    rgb.b + (255 - rgb.b) * (percent / 100)
  );
}

export function darkenColor(hex, percent) {
  const rgb = hexToRgb(hex);
  return rgbToHex(
    rgb.r * (1 - percent / 100),
    rgb.g * (1 - percent / 100),
    rgb.b * (1 - percent / 100)
  );
}

// === Математика 3D проекции ===
export function projectPoint(worldX, worldY, worldZ, props, canvasWidth, canvasHeight) {
  const {
    cameraYaw = 45,
    cameraPitch = 30,
    cameraDistance = 600,
    focusX = 0,
    focusY = 0,
    focusZ = 0,
    zoomScale = 1,
  } = props;

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

export function unprojectToGroundPlane(screenX, screenY, targetZ, props, canvasWidth, canvasHeight) {
  const {
    cameraYaw = 45,
    cameraPitch = 30,
    cameraDistance = 600,
    focusX = 0,
    focusY = 0,
    focusZ = 0,
    zoomScale = 1,
  } = props;

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

  return { worldX: rx + focusX, worldY: ry + focusY, worldZ: targetZ };
}
