import { useEffect, useState, useCallback } from 'react';

import { useBackend } from '../backend';
import { Box, Button, Flex, NoticeBox, Section } from 'tgui-core/components';
import { Window } from '../layouts';
import { SupercruiseMapCanvas } from '../components/SupercruiseMapCanvas';

interface MapObject {
  id: string;
  name: string;
  position: number[];
  position_x?: number;
  position_y?: number;
  position_z?: number;
  velocity: number[];
  velocity_x?: number;
  velocity_y?: number;
  velocity_z?: number;
  radius: number;
  render_mode: string;
  vel_mult: number;
  priority: number;
  supercruise_color: string;
  system_id?: string;
  docking_range?: number;
  position_history?: Array<number[]>;
  thrust_vector?: number[];
  thrust_angle?: number;
  thrust_pitch?: number;
  thrust_power?: number;
  heading?: number;
  heading_pitch?: number;
  max_speed?: number;
}

interface NearbyObject {
  id: string;
  name: string;
  distance: number;
  type: string;
  occupied: boolean;
}

interface JumpDestination {
  id: string;
  name: string;
  description: string;
}

interface SupercruiseMapData {
  map_objects: MapObject[];
  linkedToShuttle: boolean;
  shuttleName: string;
  shuttleAngle: number;
  shuttlePitch: number;
  shuttleThrust: number;
  shuttleHeading: number;
  shuttleHeadingPitch: number;
  shuttleMaxSpeed: number;
  shuttleVelX: number;
  shuttleVelY: number;
  shuttleVelZ: number;
  update_index: number;
  ourObject: MapObject | null;
  autopilotEnabled: boolean;
  targetX: number | null;
  targetY: number | null;
  targetZ: number | null;
  isDocked: boolean;
  dockedStation: string | null;
  nearbyStations: NearbyObject[];
  nearbyObjects: NearbyObject[];
  hasJumpDrive: boolean;
  isJumping: boolean;
  jumpCooldown: number;
  jumpReady: boolean;
  jumpCooldownRemaining: number;
  jumpDestinations: JumpDestination[];
  currentSystemName: string;
  lastActionError: string;
}

/**
 * Supercruise flight console UI
 * Homeworld-style 3D map with orbit camera
 */
export const SupercruiseMap = (props) => {
  const { act, data } = useBackend<SupercruiseMapData>();
  const {
    map_objects = [],
    linkedToShuttle = false,
    shuttleName = '',
    shuttleAngle = 0,
    shuttlePitch = 0,
    shuttleThrust = 0,
    shuttleHeading = 0,
    shuttleHeadingPitch = 0,
    shuttleMaxSpeed = 50,
    shuttleVelX = 0,
    shuttleVelY = 0,
    shuttleVelZ = 0,
    update_index = 0,
    ourObject = null,
    autopilotEnabled = false,
    targetX = null,
    targetY = null,
    targetZ = null,
    isDocked = false,
    dockedStation = null,
    nearbyStations = [],
    nearbyObjects = [],
    hasJumpDrive = false,
    isJumping = false,
    jumpReady = true,
    jumpCooldownRemaining = 0,
    jumpDestinations = [],
    currentSystemName = 'Unknown',
    lastActionError = '',
  } = data;

  // Camera state
  const [cameraYaw, setCameraYaw] = useState(45);
  const [cameraPitch, setCameraPitch] = useState(30);
  const [zoomScale, setZoomScale] = useState(1);
  const [selectedJumpDestination, setSelectedJumpDestination] = useState<string | null>(null);
  const [actionError, setActionError] = useState('');

  // Update action error from backend
  useEffect(() => {
    if (lastActionError) {
      setActionError(lastActionError);
      const timer = setTimeout(() => setActionError(''), 3000);
      return () => clearTimeout(timer);
    }
  }, [lastActionError, update_index]);

  // Our shuttle position for camera focus
  const ourPos = ourObject
    ? (ourObject.position || [ourObject.position_x || 0, ourObject.position_y || 0, ourObject.position_z || 0])
    : [0, 0, 0];

  // Camera focus point (follows our shuttle)
  const focusX = linkedToShuttle ? ourPos[0] : 0;
  const focusY = linkedToShuttle ? ourPos[1] : 0;
  const focusZ = linkedToShuttle ? ourPos[2] : 0;

  // Keyboard controls for altitude, kill thrust, and rotation toggles
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (!linkedToShuttle || isDocked) return;
      if (document.activeElement && ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement.tagName)) return;

      switch (event.key.toLowerCase()) {
        case ' ':
        case 'q':
          event.preventDefault();
          act('adjust_altitude', { dz: 10 });
          break;
        case 'e':
        case 'c':
          event.preventDefault();
          act('adjust_altitude', { dz: -10 });
          break;
        case 'x':
          event.preventDefault();
          act('kill_thrust');
          break;
        case 'a':
        case 'ф':
          event.preventDefault();
          act('toggle_rotate_left', { enable: true });
          break;
        case 'd':
        case 'в':
          event.preventDefault();
          act('toggle_rotate_right', { enable: true });
          break;
        case 'w':
        case 'ц':
          event.preventDefault();
          act('toggle_rotate_pitch_up', { enable: true });
          break;
        case 's':
        case 'ы':
          event.preventDefault();
          act('toggle_rotate_pitch_down', { enable: true });
          break;
      }
    };

    const handleKeyUp = (event: KeyboardEvent) => {
      if (!linkedToShuttle || isDocked) return;

      switch (event.key.toLowerCase()) {
        case 'a':
        case 'ф':
          act('toggle_rotate_left', { enable: false });
          break;
        case 'd':
        case 'в':
          act('toggle_rotate_right', { enable: false });
          break;
        case 'w':
        case 'ц':
          act('toggle_rotate_pitch_up', { enable: false });
          break;
        case 's':
        case 'ы':
          act('toggle_rotate_pitch_down', { enable: false });
          break;
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
    };
  }, [linkedToShuttle, isDocked, act]);

  const clampPitch = (value: number) => Math.max(5, Math.min(85, value));

  const rotateCamera = useCallback((dyaw: number, dpitch: number) => {
    setCameraYaw((prev) => (prev + dyaw + 360) % 360);
    setCameraPitch((prev) => clampPitch(prev + dpitch));
  }, []);

  const handleZoom = useCallback((factor: number) => {
    setZoomScale((prev) => Math.max(0.1, Math.min(10, prev * factor)));
  }, []);

  // Calculate 3D velocity
  const velocity3D = Math.sqrt(shuttleVelX ** 2 + shuttleVelY ** 2 + shuttleVelZ ** 2);
  const velocityHoriz = Math.sqrt(shuttleVelX ** 2 + shuttleVelY ** 2);
  const velocityAngle = velocityHoriz > 0.01
    ? (Math.atan2(shuttleVelY, shuttleVelX) * 180 / Math.PI + 360) % 360
    : 0;
  const velocityPitchAngle = velocity3D > 0.01
    ? Math.asin(Math.max(-1, Math.min(1, shuttleVelZ / velocity3D))) * 180 / Math.PI
    : 0;

  // Normalize map_objects for canvas (position can be array or separate fields)
  const canvasMapObjects = map_objects.map((obj) => {
    const pos = obj.position && Array.isArray(obj.position)
      ? obj.position
      : [obj.position_x || 0, obj.position_y || 0, obj.position_z || 0];
    const vel = obj.velocity && Array.isArray(obj.velocity)
      ? obj.velocity
      : [obj.velocity_x || 0, obj.velocity_y || 0, obj.velocity_z || 0];
    return {
      ...obj,
      position_x: pos[0],
      position_y: pos[1],
      position_z: pos[2] || 0,
      velocity_x: vel[0],
      velocity_y: vel[1],
      velocity_z: vel[2] || 0,
    };
  });

  // Our object for canvas
  const ourObjectNormalized = ourObject ? {
    ...ourObject,
    position: ourObject.position || [ourObject.position_x || 0, ourObject.position_y || 0, ourObject.position_z || 0],
    velocity: ourObject.velocity || [ourObject.velocity_x || 0, ourObject.velocity_y || 0, ourObject.velocity_z || 0],
  } : null;

  // Current shuttle Z position for display
  const shuttleAlt = ourPos[2] || 0;

  return (
    <Window width={1100} height={750}>
      <Window.Content>
        <Flex height="100%">
          <Flex.Item grow>
            <Box position="relative" height="100%" backgroundColor="#0a0a1a">
              <SupercruiseMapCanvas
                map_objects={canvasMapObjects}
                update_index={update_index}
                zoomScale={zoomScale}
                shuttleAngle={shuttleAngle}
                shuttlePitch={shuttlePitch}
                shuttleThrust={shuttleThrust}
                shuttleHeading={shuttleHeading}
                shuttleHeadingPitch={shuttleHeadingPitch}
                shuttleMaxSpeed={shuttleMaxSpeed}
                ourObject={ourObjectNormalized}
                targetX={targetX}
                targetY={targetY}
                targetZ={targetZ}
                isDocked={isDocked}
                autopilotEnabled={autopilotEnabled}
                cameraYaw={cameraYaw}
                cameraPitch={cameraPitch}
                cameraDistance={600}
                focusX={focusX}
                focusY={focusY}
                focusZ={focusZ}
                shuttleVelX={shuttleVelX}
                shuttleVelY={shuttleVelY}
                shuttleVelZ={shuttleVelZ}
                shuttleAlt={shuttleAlt}
                onRotate={rotateCamera}
                onZoom={handleZoom}
                onMapClick={(worldX, worldY, clickType, altKey, objectId) => {
                  if (isDocked) return;
                  if (clickType === 'right') {
                    // Use shuttle's current Z for autopilot target altitude
                    const targetZ = ourPos[2] || 0;
                    if (altKey) {
                      act('setTargetCoords', { x: worldX, y: worldY, z: targetZ, altKey: true });
                    } else {
                      act('setTargetCoords', { x: worldX, y: worldY, z: targetZ });
                    }
                  }
                  if (clickType === 'double' && objectId) {
                    act('dock', { stationId: objectId });
                  }
                }}
              />
            </Box>
          </Flex.Item>

          <Flex.Item width="240px" style={{ overflowY: 'auto', maxHeight: '100%' }}>
            <Section title="Flight Controls" height="100%">
              {!linkedToShuttle ? (
                <NoticeBox>No shuttle linked</NoticeBox>
              ) : (
                <>
                  {actionError && (
                    <NoticeBox color="red" mb={0.5} fontSize="0.8em">
                      {actionError}
                    </NoticeBox>
                  )}
                  <Box bold mb={0.5} fontSize="1em" color="cyan">
                    {shuttleName}
                  </Box>

                  {/* Compact position readout */}
                  <Box mb={0.5} fontSize="0.8em" color="label">
                    POS {ourPos[0]?.toFixed(0)},{ourPos[1]?.toFixed(0)},Z{ourPos[2]?.toFixed(0)}
                  </Box>

                  {/* Thrust Controls — toggle buttons for rotation */}
                  <Box mb={0.5}>
                    <Flex wrap="wrap" gap={0.5} mb={0.5}>
                      <Box bold fontSize="0.75em" color="label" style={{ width: '100%' }}>Rotation (hold):</Box>
                      <Button
                        compact
                        icon="rotate-left"
                        color="yellow"
                        disabled={isDocked}
                        onMouseDown={() => act('toggle_rotate_left', { enable: true })}
                        onMouseUp={() => act('toggle_rotate_left', { enable: false })}
                        onMouseLeave={() => act('toggle_rotate_left', { enable: false })}
                        tooltip="Hold to rotate left (A)"
                      >
                        ←
                      </Button>
                      <Button
                        compact
                        icon="rotate-right"
                        color="yellow"
                        disabled={isDocked}
                        onMouseDown={() => act('toggle_rotate_right', { enable: true })}
                        onMouseUp={() => act('toggle_rotate_right', { enable: false })}
                        onMouseLeave={() => act('toggle_rotate_right', { enable: false })}
                        tooltip="Hold to rotate right (D)"
                      >
                        →
                      </Button>
                      <Button
                        compact
                        icon="angle-double-up"
                        color="yellow"
                        disabled={isDocked}
                        onMouseDown={() => act('toggle_rotate_pitch_up', { enable: true })}
                        onMouseUp={() => act('toggle_rotate_pitch_up', { enable: false })}
                        onMouseLeave={() => act('toggle_rotate_pitch_up', { enable: false })}
                        tooltip="Hold to pitch up (W)"
                      >
                        ↑
                      </Button>
                      <Button
                        compact
                        icon="angle-double-down"
                        color="yellow"
                        disabled={isDocked}
                        onMouseDown={() => act('toggle_rotate_pitch_down', { enable: true })}
                        onMouseUp={() => act('toggle_rotate_pitch_down', { enable: false })}
                        onMouseLeave={() => act('toggle_rotate_pitch_down', { enable: false })}
                        tooltip="Hold to pitch down (S)"
                      >
                        ↓
                      </Button>
                    </Flex>
                    <Flex wrap="wrap" gap={0.5}>
                      <Button
                        compact
                        icon="arrow-up"
                        disabled={isDocked}
                        onClick={() => act('set_thrust', {
                          angle: shuttleAngle,
                          power: Math.min(shuttleThrust + 10, 100),
                          pitch: shuttlePitch || 0,
                        })}
                        tooltip="Thrust +10%"
                      >
                        +Pwr
                      </Button>
                      <Button
                        compact
                        icon="arrow-down"
                        disabled={isDocked}
                        onClick={() => act('set_thrust', {
                          angle: shuttleAngle,
                          power: Math.max(shuttleThrust - 10, 0),
                          pitch: shuttlePitch || 0,
                        })}
                        tooltip="Thrust -10%"
                      >
                        -Pwr
                      </Button>
                      <Button
                        compact
                        icon="arrow-up"
                        color="teal"
                        disabled={isDocked}
                        onClick={() => act('adjust_altitude', { dz: 10 })}
                        tooltip="Ascend (Q/Space)"
                      >
                        ↑Alt
                      </Button>
                      <Button
                        compact
                        icon="arrow-down"
                        color="teal"
                        disabled={isDocked}
                        onClick={() => act('adjust_altitude', { dz: -10 })}
                        tooltip="Descend (E/C)"
                      >
                        ↓Alt
                      </Button>
                      <Button
                        fluid
                        compact
                        icon="xmark"
                        color="red"
                        disabled={isDocked}
                        onClick={() => act('kill_thrust')}
                        tooltip="Kill Thrust (X)"
                      >
                        STOP
                      </Button>
                    </Flex>
                  </Box>

                  {/* Zoom */}
                  <Flex mb={0.5}>
                    <Button compact icon="search-plus" onClick={() => handleZoom(1.3)} tooltip="Zoom In" />
                    <Button compact icon="search-minus" onClick={() => handleZoom(0.7)} tooltip="Zoom Out" />
                    <Box as="span" ml={1} fontSize="0.8em" color="label" lineHeight="22px">
                      Zoom: {zoomScale.toFixed(1)}x
                    </Box>
                  </Flex>

                  {/* Status */}
                  {isDocked ? (
                    <NoticeBox color="red" fontSize="0.8em" mt={0.5}>
                      DOCKED — {dockedStation}
                    </NoticeBox>
                  ) : (
                    <NoticeBox color={autopilotEnabled ? 'green' : 'purple'} fontSize="0.8em" mt={0.5}>
                      {autopilotEnabled
                        ? `AUTOPILOT → (${targetX?.toFixed(0)}, ${targetY?.toFixed(0)}, Z${(targetZ || 0).toFixed(0)})`
                        : 'Right-click map → autopilot'}
                    </NoticeBox>
                  )}

                  {isDocked && (
                    <Button
                      fluid
                      icon="anchor"
                      color="red"
                      mt={0.5}
                      onClick={() => act('undock')}
                    >
                      Undock
                    </Button>
                  )}

                  {/* Nearby Objects — compact list */}
                  {!isDocked && nearbyObjects?.length > 0 && (
                    <Box mt={0.5}>
                      <Box bold fontSize="0.8em" color="label">Contacts:</Box>
                      {nearbyObjects.map((obj) => (
                        <Flex key={obj.id} align="center" justify="space-between" mb={0.25}>
                          <Box fontSize="0.8em">
                            <Box as="span" color={
                              obj.type === 'station' ? 'blue' :
                              obj.type === 'planet' ? 'green' : 'gray'
                            }>●</Box>{' '}
                            {obj.name}
                            <Box as="span" color="label" ml={1}>{obj.distance}km</Box>
                          </Box>
                          {obj.type === 'station' && (
                            <Button
                              compact
                              fontSize="0.75em"
                              icon="anchor"
                              disabled={obj.occupied || obj.distance > 20}
                              onClick={() => act('dock', { stationId: obj.id })}
                            >
                              {obj.occupied ? 'Occupied' : obj.distance > 20 ? 'Too far' : 'Dock'}
                            </Button>
                          )}
                        </Flex>
                      ))}
                    </Box>
                  )}

                  {/* Jump Drive */}
                  {hasJumpDrive && (
                    <Box mt={0.5}>
                      <Box bold fontSize="0.8em" color="label">
                        Jump Drive: {currentSystemName}
                      </Box>
                      {isJumping ? (
                        <Box color="orange" fontSize="0.8em">Jump in progress...</Box>
                      ) : !jumpReady ? (
                        <Box color="red" fontSize="0.8em">Cooldown: {Math.ceil(jumpCooldownRemaining)}s</Box>
                      ) : isDocked ? (
                        <Box color="red" fontSize="0.8em">Undock first</Box>
                      ) : jumpDestinations.length === 0 ? (
                        <Box color="gray" fontSize="0.8em">No destinations</Box>
                      ) : (
                        <Flex mt={0.5}>
                          <Flex.Item grow>
                            <select
                              style={{
                                width: '100%', padding: '2px',
                                backgroundColor: '#1a1a2e', color: '#fff',
                                border: '1px solid #444', borderRadius: '2px',
                                fontSize: '0.8em',
                              }}
                              value={selectedJumpDestination || ''}
                              onChange={(e) => setSelectedJumpDestination(e.target.value)}
                            >
                              <option value="">-- System --</option>
                              {jumpDestinations.map((dest) => (
                                <option key={dest.id} value={dest.id}>{dest.name}</option>
                              ))}
                            </select>
                          </Flex.Item>
                          <Flex.Item ml={0.5}>
                            <Button
                              compact
                              icon="rocket"
                              color="purple"
                              disabled={!selectedJumpDestination}
                              onClick={() => {
                                if (selectedJumpDestination) {
                                  act('jump', { systemId: selectedJumpDestination });
                                  setSelectedJumpDestination(null);
                                }
                              }}
                            >
                              Jump
                            </Button>
                          </Flex.Item>
                        </Flex>
                      )}
                    </Box>
                  )}

                  <Box mt={1} fontSize="0.7em" color="dim">
                    Drag=rotate · Wheel=zoom · RClick=fly<br />
                    WASD=rotate (hold) · Q/Space=ascend · E/C=descend · X=stop
                  </Box>
                </>
              )}
            </Section>
          </Flex.Item>
        </Flex>
      </Window.Content>
    </Window>
  );
};
