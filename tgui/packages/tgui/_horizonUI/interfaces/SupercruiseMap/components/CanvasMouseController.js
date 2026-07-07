export class CanvasMouseController {
  constructor(getCanvas, getProps, projectPoint, unprojectToGroundPlane) {
    this.getCanvas = getCanvas;
    this.getProps = getProps;
    this.projectPoint = projectPoint;
    this.unprojectToGroundPlane = unprojectToGroundPlane;

    this.dragging = false;
    this.lastDragPos = null;
    this.lastClickPos = null;
    this.hoveredObjectId = null;
    this.mouseScreenPos = null;

    // Состояния для Ctrl+ПКМ выбора высоты
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

  handleMouseDown = (e) => {
    const props = this.getProps();
    if (e.button === 0) {
      e.preventDefault();
      this.dragging = true;
      this.lastDragPos = { x: e.clientX, y: e.clientY };
    } else if (e.button === 2) {
      e.preventDefault();
      if (e.shiftKey) {
        return;
      } else if (e.ctrlKey) {
        this.adjustingZ = true;
        this.adjustZStartY = e.clientY;
        const rect = this.getCanvas().getBoundingClientRect();
        const clickX = e.clientX - rect.left;
        const clickY = e.clientY - rect.top;
        const { worldX, worldY } = this.unprojectToGroundPlane(clickX, clickY, 0);
        this.adjustWorldX = worldX;
        this.adjustWorldY = worldY;
        this.adjustBaseZ = 0;
        this.adjustCurrentZ = 0;
        this.localPendingX = worldX;
        this.localPendingY = worldY;
        this.localPendingZ = 0;
      } else {
        this.normalRightClicked = true;
      }
    }
  };

  handleMouseMove = (e) => {
    const props = this.getProps();
    if (this.adjustingZ) {
      const dy = e.clientY - this.adjustZStartY;
      const zScale = 2 / (props.zoomScale || 1);
      this.adjustCurrentZ = this.adjustBaseZ - dy * zScale;
      this.localPendingZ = this.adjustCurrentZ;
      return;
    }
    if (this.dragging && this.lastDragPos && props.onRotate) {
      const dx = e.clientX - this.lastDragPos.x;
      const dy = e.clientY - this.lastDragPos.y;
      this.lastDragPos = { x: e.clientX, y: e.clientY };
      props.onRotate(dx * 0.3, dy * 0.25);
    } else {
      const canvas = this.getCanvas();
      if (!canvas) return;
      const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left;
      const my = e.clientY - rect.top;
      this.mouseScreenPos = { x: mx, y: my };
      let closestId = null;
      let closestDist = 15;
      const map_objects = props.map_objects || [];

      for (const obj of map_objects) {
        const posX = obj.position_x ?? 0;
        const posY = obj.position_y ?? 0;
        const posZ = obj.position_z ?? 0;
        const isStatic = obj.render_mode === 'station' || obj.render_mode === 'planet';
        const velX = isStatic ? 0 : (obj.velocity_x ?? 0);
        const velY = isStatic ? 0 : (obj.velocity_y ?? 0);
        const velZ = isStatic ? 0 : (obj.velocity_z ?? 0);
        const elapsed = this.currentElapsed || 0;
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

  handleMouseUp = (e) => {
    const props = this.getProps();
    if (e.button === 0) {
      this.dragging = false;
      this.lastDragPos = null;
    } else if (e.button === 2) {
      if (this.adjustingZ) {
        this.adjustingZ = false;
        if (props.onMapClick) {
          props.onMapClick(this.adjustWorldX, this.adjustWorldY, 'right', false, null, this.adjustCurrentZ);
        }
        this.localPendingX = null;
        this.localPendingY = null;
        this.localPendingZ = null;
      } else if (e.shiftKey) {
        if (props.onMapClick) {
          props.onMapClick(0, 0, 'cancel', true, null, 0);
        }
      } else if (this.normalRightClicked) {
        if (props.onMapClick) {
          const rect = this.getCanvas().getBoundingClientRect();
          const clickX = e.clientX - rect.left;
          const clickY = e.clientY - rect.top;
          const { worldX, worldY } = this.unprojectToGroundPlane(clickX, clickY, 0);
          const objectId = this.hoveredObjectId;
          props.onMapClick(worldX, worldY, 'right', false, objectId, 0);
        }
        this.normalRightClicked = false;
      }
    }
  };

  handleWheel = (e) => {
    const props = this.getProps();
    e.preventDefault();
    if (props.onZoom) {
      const delta = e.deltaY > 0 ? 0.9 : 1.1;
      props.onZoom(delta);
    }
  };

  handleContextMenu = (e) => {
    e.preventDefault();
  };

  handleDoubleClick = (e) => {
    const props = this.getProps();
    if (!props.onMapClick) return;
    e.preventDefault();
    const rect = this.getCanvas().getBoundingClientRect();
    const clickX = e.clientX - rect.left;
    const clickY = e.clientY - rect.top;
    const { worldX, worldY } = this.unprojectToGroundPlane(clickX, clickY, 0);
    const objectId = this.hoveredObjectId;
    props.onMapClick(worldX, worldY, 'double', e.altKey, objectId, 0);
  };
}
