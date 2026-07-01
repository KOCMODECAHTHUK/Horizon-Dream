import { Component } from 'react';
/**
 * Hey folks I am not good with tgui this was made with the help of some AI shit
 * so please like yell at me if anything looks like dogshit
 */
const FPS = 30; // Increased from 20 to 30 for smoother animation

/**
 * Renders orbital objects on an SVG canvas
 * Updates at 30 FPS for smooth interpolation
 */
export class SupercruiseMapSvg extends Component {
  constructor(props) {
    super(props);
    this.state = {
      tickIndex: -1,
      tickTimer: new Date(),
      objects: {},
    };
    this.dragging = false;
    this.lastDragPos = null;
  }

  componentDidMount() {
    // Trigger re-renders at 30 FPS for smooth interpolation
    this.renderUpdate = setInterval(() => this.forceUpdate(), 1000 / FPS);
  }

  componentWillUnmount() {
    clearInterval(this.renderUpdate);
  }

  componentDidUpdate(prevProps) {
    const { update_index, map_objects = [] } = this.props;

    // Only update state when we get a new server update
    if (prevProps.update_index !== update_index) {
      const newObjects = {};

      // Store the new positions from the server
      map_objects.forEach((obj) => {
        newObjects[obj.id] = {
          id: obj.id,
          name: obj.name,
          position_x: obj.position_x,
          position_y: obj.position_y,
          position_z: obj.position_z,
          velocity_x: obj.velocity_x,
          velocity_y: obj.velocity_y,
          velocity_z: obj.velocity_z,
          radius: obj.radius,
          render_mode: obj.render_mode,
          position_history: obj.position_history,
          docking_range: obj.docking_range,
          supercruise_color: obj.supercruise_color,
        };
      });

      this.setState({
        tickIndex: update_index,
        tickTimer: new Date(),
        objects: newObjects,
      });
    }
  }

  render() {
    const {
      xOffset = 0,
      yOffset = 0,
      zOffset = 0,
      zoomScale = 1,
      shuttleAngle = 0,
      shuttleThrust = 0,
      ourObject = null,
      cameraYaw = 45,
      cameraPitch = 20,
      onMapClick = null,
      onRotate = null,
      targetX = null,
      targetY = null,
      targetZ = null,
      isDocked = false,
      autopilotEnabled = false,
    } = this.props;
    const { tickIndex, tickTimer, objects } = this.state;
    const { update_index } = this.props;

    // Calculate interpolation elapsed time
    // Cap at 0.5 seconds (the server update interval) to prevent extrapolation beyond the next update
    let elapsed = 0;
    if (tickIndex === update_index) {
      const now = new Date();
      elapsed = Math.min((now - tickTimer) / 1000, 0.5);
    }

    // Calculate spinning angle for autopilot target (continuous rotation)
    const spinAngle = (Date.now() / 20) % 360;

    const projectPoint = (worldX, worldY, worldZ) => {
      const radYaw = cameraYaw * Math.PI / 180;
      const radPitch = cameraPitch * Math.PI / 180;
      const cosY = Math.cos(radYaw);
      const sinY = Math.sin(radYaw);
      const cosP = Math.cos(radPitch);
      const sinP = Math.sin(radPitch);

      const rx = worldX * cosY - worldY * sinY;
      const ry = worldX * sinY + worldY * cosY;
      const rz = worldZ;
      const screenY = ry * cosP - rz * sinP;
      const screenZ = ry * sinP + rz * cosP;

      return {
        x: (rx + xOffset) * zoomScale,
        y: (screenY + yOffset) * zoomScale,
        depth: screenZ,
      };
    };

    const unprojectGroundPoint = (screenX, screenY) => {
      const radYaw = cameraYaw * Math.PI / 180;
      const radPitch = cameraPitch * Math.PI / 180;
      const cosY = Math.cos(radYaw);
      const sinY = Math.sin(radYaw);
      const cosP = Math.cos(radPitch);

      const rx = screenX / zoomScale - xOffset;
      const ry = (screenY / zoomScale - yOffset) / cosP;
      const worldX = rx * cosY + ry * sinY;
      const worldY = -rx * sinY + ry * cosY;
      return { worldX, worldY };
    };

    const handlePointerMove = (event) => {
      if (!this.dragging || !this.lastDragPos || !onRotate) return;
      const svg = event.currentTarget;
      const rect = svg.getBoundingClientRect();
      const x = event.clientX - rect.left;
      const y = event.clientY - rect.top;
      const dx = x - this.lastDragPos.x;
      const dy = y - this.lastDragPos.y;
      this.lastDragPos = { x, y };
      onRotate(dx * 0.3, dy * 0.25);
    };

    const handlePointerUp = () => {
      this.dragging = false;
      this.lastDragPos = null;
    };

    const handleContextMenu = (e) => {
      if (!onMapClick) return;
      e.preventDefault();
      const svg = e.currentTarget;
      const rect = svg.getBoundingClientRect();
      const clickX = ((e.clientX - rect.left) / rect.width) * 500 - 250;
      const clickY = ((e.clientY - rect.top) / rect.height) * 500 - 250;
      const { worldX, worldY } = unprojectGroundPoint(clickX, clickY);
      onMapClick(worldX, worldY, 'right', e.altKey);
    };

    return (
      <svg
        viewBox="-250 -250 500 500"
        style={{
          position: 'absolute',
          width: '100%',
          height: '100%',
          cursor: 'grab',
        }}
        onMouseDown={(e) => {
          if (e.button !== 0) return;
          e.preventDefault();
          const svg = e.currentTarget;
          const rect = svg.getBoundingClientRect();
          this.dragging = true;
          this.lastDragPos = {
            x: e.clientX - rect.left,
            y: e.clientY - rect.top,
          };
        }}
        onMouseMove={handlePointerMove}
        onMouseUp={handlePointerUp}
        onMouseLeave={handlePointerUp}
        onContextMenu={handleContextMenu}
      >
        {/* Grid background and arrow markers */}
        <defs>
          <pattern
            id="grid"
            width={100 * zoomScale}
            height={100 * zoomScale}
            patternUnits="userSpaceOnUse"
          >
            <rect
              width={100 * zoomScale}
              height={100 * zoomScale}
              fill="#1a1a2e"
            />
            <path
              d={`M ${100 * zoomScale} 0 L 0 0 0 ${100 * zoomScale}`}
              fill="none"
              stroke="#2a2a4a"
              strokeWidth="1"
            />
          </pattern>

          {/* Arrow marker for velocity */}
          <marker
            id="arrowVel"
            markerWidth="10"
            markerHeight="10"
            refX="5"
            refY="3"
            orient="auto"
            markerUnits="strokeWidth"
          >
            <path d="M0,0 L0,6 L9,3 z" fill="#00ffff" />
          </marker>

          {/* Arrow marker for thrust */}
          <marker
            id="arrowThrust"
            markerWidth="10"
            markerHeight="10"
            refX="5"
            refY="3"
            orient="auto"
            markerUnits="strokeWidth"
          >
            <path d="M0,0 L0,6 L9,3 z" fill="#ffff00" />
          </marker>
        </defs>
        <rect x="-50%" y="-50%" width="100%" height="100%" fill="url(#grid)" />

        {/* Render ground plane grid */}
        {Array.from({ length: 11 }).map((_, index) => {
          const offset = (index - 5) * 50;
          const startA = projectPoint(offset, -250, 0);
          const endA = projectPoint(offset, 250, 0);
          const startB = projectPoint(-250, offset, 0);
          const endB = projectPoint(250, offset, 0);
          return (
            <g key={`plane-${index}`}>
              <line x1={startA.x} y1={startA.y} x2={endA.x} y2={endA.y} stroke="#303050" strokeWidth={0.5} opacity={0.4} />
              <line x1={startB.x} y1={startB.y} x2={endB.x} y2={endB.y} stroke="#303050" strokeWidth={0.5} opacity={0.4} />
            </g>
          );
        })}

        {/* Render all objects */}
        {Object.values(objects).map((obj) => {
          // Interpolate position for smooth movement (stations and planets don't move)
          const worldX = obj.position_x + (obj.render_mode !== 'station' && obj.render_mode !== 'planet' ? obj.velocity_x * elapsed : 0);
          const worldY = obj.position_y + (obj.render_mode !== 'station' && obj.render_mode !== 'planet' ? obj.velocity_y * elapsed : 0);
          const worldZ = obj.position_z || 0;
          const projected = projectPoint(worldX, worldY, worldZ);
          const ground = projectPoint(worldX, worldY, 0);
          const x = ground.x;
          const y = ground.y;
          const displayX = projected.x;
          const displayY = projected.y;
          const r = Math.max(2, obj.radius * zoomScale * (1 + worldZ * 0.002));

          // Color based on object's supercruise_color property, with fallbacks
          const color = obj.supercruise_color ||
            (obj.render_mode === 'shuttle' ? '#a4eea4' :
            obj.render_mode === 'station' ? '#4488ff' :
            obj.render_mode === 'planet' ? '#8B7355' : '#ffaa00');

          // Calculate if this is our shuttle
          const isOurShuttle = ourObject && obj.id === ourObject.id;
          const isStation = obj.render_mode === 'station';
          const isPlanet = obj.render_mode === 'planet';
          const altitude = obj.position_z || 0;
          const altitudeLineLength = Math.min(40, Math.max(10, Math.abs(altitude) * 1.2 + 8));
          const altitudeDirection = altitude >= 0 ? -1 : 1;
          const altitudeLineX = x + (isOurShuttle ? -(r + 6) : r + 6);
          const altitudeLineY = y + altitudeDirection * altitudeLineLength;
          const altitudeLabel = `Z:${altitude >= 0 ? '+' : ''}${altitude.toFixed(0)}km`;
          const baseRadius = Math.max(1, r * 0.6);
          const velocityTip = projectPoint(worldX + obj.velocity_x * 5, worldY + obj.velocity_y * 5, worldZ);
          const thrustTip = projectPoint(
            worldX + Math.cos(shuttleAngle * Math.PI / 180) * 20,
            worldY + Math.sin(shuttleAngle * Math.PI / 180) * 20,
            worldZ,
          );

          return (
            <g key={obj.id}>
              {/* Show position history trail for our shuttle */}
              {isOurShuttle && obj.position_history && obj.position_history.length > 1 && (
                <polyline
                  points={obj.position_history
                    .map((pos) => {
                      const proj = projectPoint(pos.x, pos.y, pos.z || 0);
                      return `${proj.x},${proj.y}`;
                    })
                    .join(' ')}
                  fill="none"
                  stroke="#a4eea4"
                  strokeWidth={1}
                  opacity={0.5}
                />
              )}

              {/* Render station differently */}
              {isStation ? (
                <>
                  <rect
                    x={x - baseRadius}
                    y={y - baseRadius}
                    width={baseRadius * 2}
                    height={baseRadius * 2}
                    fill="rgba(68, 136, 255, 0.2)"
                    stroke="#88aaff"
                    strokeWidth={1}
                  />
                  <rect
                    x={displayX - r}
                    y={displayY - r}
                    width={r * 2}
                    height={r * 2}
                    fill={color}
                    stroke="#88aaff"
                    strokeWidth={2}
                  />
                  <circle
                    cx={x}
                    cy={y}
                    r={obj.docking_range * zoomScale}
                    fill="none"
                    stroke="#88aaff"
                    strokeWidth={1}
                    strokeDasharray="5,5"
                    opacity={0.3}
                  />
                </>
              ) : isPlanet ? (
                /* Render planets as large circles with a glow effect */
                <>
                  <circle
                    cx={x}
                    cy={y}
                    r={baseRadius + 2}
                    fill="rgba(139, 115, 85, 0.15)"
                  />
                  <circle
                    cx={displayX}
                    cy={displayY}
                    r={r}
                    fill={color}
                    stroke={color}
                    strokeWidth={1}
                  />
                </>
              ) : (
                // Don't render ship circle if this is our shuttle and we're docked
                !(isDocked) && (
                  <>
                    <circle
                      cx={x}
                      cy={y}
                      r={baseRadius}
                      fill="rgba(164, 238, 164, 0.25)"
                      stroke="#a4eea4"
                      strokeWidth={1}
                    />
                    <circle cx={displayX} cy={displayY} r={r} fill={color} />
                  </>
                )
              )}

              {/* Show velocity vector (cyan line) */}
              {isOurShuttle && (obj.velocity_x !== 0 || obj.velocity_y !== 0) && (
                <line
                  x1={displayX}
                  y1={displayY}
                  x2={velocityTip.x}
                  y2={velocityTip.y}
                  stroke="#00ffff"
                  strokeWidth={2}
                  markerEnd="url(#arrowVel)"
                />
              )}

              {/* Show thrust vector (yellow line) */}
              {isOurShuttle && shuttleThrust > 0 && (
                <line
                  x1={displayX}
                  y1={displayY}
                  x2={thrustTip.x}
                  y2={thrustTip.y}
                  stroke="#ffff00"
                  strokeWidth={2}
                  markerEnd="url(#arrowThrust)"
                />
              )}

              {(altitude !== 0 || isOurShuttle) && (
                <g>
                  <line
                    x1={x}
                    y1={y}
                    x2={displayX}
                    y2={displayY}
                    stroke="#ff88ff"
                    strokeWidth={1}
                    opacity={0.45}
                  />
                  <circle
                    cx={x}
                    cy={y}
                    r={Math.max(1, baseRadius * 0.75)}
                    fill="rgba(255,136,255,0.12)"
                    stroke="#ff88ff"
                    strokeWidth={1}
                    opacity={0.5}
                  />
                  <line
                    x1={altitudeLineX}
                    y1={displayY}
                    x2={altitudeLineX}
                    y2={altitudeLineY}
                    stroke="#ff88ff"
                    strokeWidth={2}
                    opacity={0.85}
                  />
                  <circle
                    cx={altitudeLineX}
                    cy={altitudeLineY}
                    r={3}
                    fill="#ff88ff"
                  />
                  <text
                    x={altitudeLineX + (isOurShuttle ? -8 : 8)}
                    y={altitudeLineY + 4}
                    fill="#ff88ff"
                    fontSize={Math.min(10 * zoomScale, 12)}
                    textAnchor={isOurShuttle ? 'end' : 'start'}
                    opacity={0.9}
                  >
                    {altitudeLabel}
                  </text>
                </g>
              )}

              {/* Don't show name if this is our shuttle and we're docked */}
              {!(isDocked && isOurShuttle) && (
                <text
                  x={x + r + 2}
                  y={y + 4}
                  fill={color}
                  fontSize={Math.min(12 * zoomScale, 14)}
                >
                  {obj.name}{altitude !== 0 ? ` (${altitude >= 0 ? '+' : ''}${altitude.toFixed(0)}km)` : ''}
                </text>
              )}
            </g>
          );
        })}

        {/* Vertical Z legend */}
        <g transform="translate(200 -230)">
          <rect x="-10" y="0" width="120" height="90" fill="#0a0a1a" stroke="#444" strokeWidth="1" rx="6" />
          <text x="0" y="16" fill="#ffffff" fontSize="11" fontWeight="bold">Altitude legend</text>
          <line x1="10" y1="30" x2="10" y2="60" stroke="#ff88ff" strokeWidth="2" />
          <circle cx="10" cy="30" r="3" fill="#ff88ff" />
          <circle cx="10" cy="60" r="3" fill="#ff88ff" />
          <text x="24" y="34" fill="#ffffff" fontSize="10">+ above plane</text>
          <text x="24" y="64" fill="#ffffff" fontSize="10">- below plane</text>
          <text x="0" y="80" fill="#888" fontSize="10">All objects show Z height.</text>
        </g>

        {/* Show target position marker if set and autopilot is enabled */}
        {autopilotEnabled && targetX !== null && targetY !== null && (() => {
          const targetProjection = projectPoint(targetX, targetY, 0);
          return (
            <g transform={`rotate(${spinAngle} ${targetProjection.x} ${targetProjection.y})`}>
              <circle
                cx={targetProjection.x}
                cy={targetProjection.y}
                r={8}
                fill="none"
                stroke="#ff00ff"
                strokeWidth={2}
              />
              <circle
                cx={targetProjection.x}
                cy={targetProjection.y}
                r={12}
                fill="none"
                stroke="#ff00ff"
                strokeWidth={1}
                strokeDasharray="4,4"
              />
            </g>
          );
        })()}
      </svg>
    );
  }
}
