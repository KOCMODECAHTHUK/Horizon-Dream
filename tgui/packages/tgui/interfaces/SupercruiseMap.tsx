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
  } = data;

  // Camera state
  const [cameraYaw, setCameraYaw] = useState(45);
  const [cameraPitch, setCameraPitch] = useState(30);
  const [zoomScale, setZoomScale] = useState(1);
  const [selectedJumpDestination, setSelectedJumpDestination] = useState<string | null>(null);

  // Our shuttle position for camera focus
  const ourPos = ourObject
    ? (ourObject.position || [ourObject.position_x || 0, ourObject.position_y || 0, ourObject.position_z || 0])
    : [0, 0, 0];

  // Camera focus point (follows our shuttle)
  const focusX = linkedToShuttle ? ourPos[0] : 0;
  const focusY = linkedToShuttle ? ourPos[1] : 0;
  const focusZ = linkedToShuttle ? ourPos[2] : 0;

  // Keyboard controls for altitude and kill thrust
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
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
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
                onRotate={rotateCamera}
                onZoom={handleZoom}
                onMapClick={(worldX, worldY, clickType, altKey) => {
                  if (isDocked) return;
                  if (clickType === 'right') {
                    if (altKey) {
                      act('setTargetCoords', { x: worldX, y: worldY, z: focusZ, altKey: true });
                    } else {
                      act('setTargetCoords', { x: worldX, y: worldY, z: focusZ });
                    }
                  }
                }}
              />
            </Box>
          </Flex.Item>

          <Flex.Item width="280px" style={{ overflowY: 'auto', maxHeight: '100%' }}>
            <Section title="Flight Controls" height="100%">
              {!linkedToShuttle ? (
                <NoticeBox>No shuttle linked to console</NoticeBox>
              ) : (
                <>
                  <Box bold mb={1} fontSize="1.1em">
                    {shuttleName}
                  </Box>

                  {/* Position & Velocity */}
                  <Box mb={1} fontSize="0.9em">
                    <Box>
                      <Box as="span" color="label">POS:</Box>{' '}
                      {ourPos[0]?.toFixed(1)}, {ourPos[1]?.toFixed(1)}, Z{ourPos[2]?.toFixed(1)}
                    </Box>
                    <Box>
                      <Box as="span" color="label">VEL:</Box>{' '}
                      {shuttleVelX.toFixed(1)}, {shuttleVelY.toFixed(1)}, {shuttleVelZ.toFixed(1)}
                    </Box>
                    <Box color="cyan">
                      {velocity3D.toFixed(1)} km/s @ {velocityAngle.toFixed(0)}° pitch {velocityPitchAngle.toFixed(0)}°
                    </Box>
                  </Box>

                  {/* Altitude */}
                  <Box mb={1}>
                    <Box bold fontSize="0.9em">
                      Altitude: {shuttleAlt.toFixed(1)} km
                    </Box>
                    <div style={{
                      width: '100%', height: '8px', background: '#111',
                      border: '1px solid #444', borderRadius: '4px', position: 'relative',
                    }}>
                      <div style={{
                        position: 'absolute', left: '50%', top: 0, bottom: 0,
                        width: '2px', background: '#555',
                      }} />
                      <div style={{
                        position: 'absolute',
                        left: `${50 + Math.max(-45, Math.min(45, shuttleAlt / 2))}%`,
                        top: 0, bottom: 0, width: '4px', background: '#ff88ff',
                        transform: 'translateX(-50%)',
                      }} />
                    </div>
                    <Flex mt={0.5}>
                      <Button
                        compact
                        icon="arrow-up"
                        disabled={isDocked}
                        onClick={() => act('adjust_altitude', { dz: 10 })}
                        tooltip="Ascend (Q/Space)"
                      />
                      <Button
                        compact
                        icon="arrow-down"
                        disabled={isDocked}
                        onClick={() => act('adjust_altitude', { dz: -10 })}
                        tooltip="Descend (E/C)"
                      />
                    </Flex>
                  </Box>

                  {/* Thrust Controls */}
                  <Box mb={1}>
                    <Box bold fontSize="0.9em">
                      Thrust: {shuttleAngle}° / {shuttlePitch || 0}° @ {shuttleThrust}%
                    </Box>
                    <Flex mt={0.5} wrap="wrap">
                      <Button
                        compact
                        icon="rotate-left"
                        disabled={isDocked}
                        onClick={() => act('set_thrust', {
                          angle: (shuttleAngle - 15 + 360) % 360,
                          power: shuttleThrust,
                          pitch: shuttlePitch || 0,
                        })}
                      >
                        -15°
                      </Button>
                      <Button
                        compact
                        icon="rotate-right"
                        disabled={isDocked}
                        onClick={() => act('set_thrust', {
                          angle: (shuttleAngle + 15) % 360,
                          power: shuttleThrust,
                          pitch: shuttlePitch || 0,
                        })}
                      >
                        +15°
                      </Button>
                      <Button
                        compact
                        icon="arrow-up"
                        disabled={isDocked}
                        onClick={() => act('set_thrust', {
                          angle: shuttleAngle,
                          power: Math.min(shuttleThrust + 10, 100),
                          pitch: shuttlePitch || 0,
                        })}
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
                      >
                        -Pwr
                      </Button>
                      <Button
                        compact
                        icon="xmark"
                        color="red"
                        disabled={isDocked}
                        onClick={() => act('kill_thrust')}
                        tooltip="Kill Thrust (X)"
                      >
                        STOP
                      </Button>
                      <Button
                        compact
                        icon="angle-double-up"
                        disabled={isDocked}
                        onClick={() => act('set_thrust', {
                          angle: shuttleAngle,
                          power: shuttleThrust,
                          pitch: Math.min((shuttlePitch || 0) + 15, 90),
                        })}
                      >
                        Pitch+
                      </Button>
                      <Button
                        compact
                        icon="angle-double-down"
                        disabled={isDocked}
                        onClick={() => act('set_thrust', {
                          angle: shuttleAngle,
                          power: shuttleThrust,
                          pitch: Math.max((shuttlePitch || 0) - 15, -90),
                        })}
                      >
                        Pitch-
                      </Button>
                    </Flex>
                  </Box>

                  {/* Zoom */}
                  <Flex mb={1}>
                    <Flex.Item grow>
                      <Box bold fontSize="0.9em">Zoom</Box>
                    </Flex.Item>
                    <Flex.Item>
                      <Button compact icon="search-plus" onClick={() => handleZoom(1.3)} />
                      <Button compact icon="search-minus" onClick={() => handleZoom(0.7)} />
                    </Flex.Item>
                  </Flex>

                  {/* Status */}
                  <Box mt={1} mb={1}>
                    {isDocked ? (
                      <NoticeBox color="red" fontSize="0.85em">
                        DOCKED — Flight controls locked
                      </NoticeBox>
                    ) : (
                      <NoticeBox color={autopilotEnabled ? 'green' : 'purple'} fontSize="0.85em">
                        {autopilotEnabled
                          ? `AUTOPILOT → (${targetX?.toFixed(0)}, ${targetY?.toFixed(0)}, Z${(targetZ || 0).toFixed(0)})`
                          : 'Right-click map to fly. Alt+Click to cancel.'}
                      </NoticeBox>
                    )}
                  </Box>

                  {/* Docking/Interaction */}
                  <Box mt={1}>
                    {isDocked ? (
                      <>
                        <NoticeBox color="teal" fontSize="0.85em">
                          Docked at {dockedStation}
                        </NoticeBox>
                        <Button
                          fluid
                          icon="anchor"
                          color="red"
                          onClick={() => act('undock')}
                        >
                          Undock
                        </Button>
                      </>
                    ) : nearbyObjects?.length > 0 ? (
                      <>
                        <Box bold mb={0.5} fontSize="0.9em">Nearby Objects:</Box>
                        {nearbyObjects.map((obj) => (
                          <Box key={obj.id} mb={0.5} fontSize="0.85em">
                            <Flex align="center" justify="space-between">
                              <Flex.Item>
                                {obj.name}{' '}
                                <Box as="span" color={
                                  obj.type === 'station' ? 'blue' :
                                  obj.type === 'planet' ? 'green' : 'gray'
                                }>
                                  [{obj.type}]
                                </Box>
                              </Flex.Item>
                              <Flex.Item>
                                <Button
                                  compact
                                  icon={obj.type === 'station' ? 'anchor' : 'hand-pointer'}
                                  disabled={obj.occupied && obj.type === 'station'}
                                  onClick={() => act('dock', { stationId: obj.id })}
                                >
                                  {obj.distance}km
                                </Button>
                              </Flex.Item>
                            </Flex>
                          </Box>
                        ))}
                      </>
                    ) : (
                      <Box color="gray" fontSize="0.85em">No objects in range</Box>
                    )}
                  </Box>

                  {/* Jump Drive */}
                  {hasJumpDrive && (
                    <Box mt={1}>
                      <Box bold mb={0.5} fontSize="0.9em">Jump Drive</Box>
                      <Box fontSize="0.85em" color="cyan" mb={0.5}>
                        System: {currentSystemName}
                      </Box>
                      {isJumping ? (
                        <NoticeBox color="orange" fontSize="0.85em">Jump in progress...</NoticeBox>
                      ) : !jumpReady ? (
                        <NoticeBox color="red" fontSize="0.85em">
                          Cooldown: {Math.ceil(jumpCooldownRemaining)}s
                        </NoticeBox>
                      ) : isDocked ? (
                        <NoticeBox color="red" fontSize="0.85em">Undock first</NoticeBox>
                      ) : jumpDestinations.length === 0 ? (
                        <Box color="gray" fontSize="0.85em">No destinations</Box>
                      ) : (
                        <>
                          <select
                            style={{
                              width: '100%', padding: '4px',
                              backgroundColor: '#1a1a2e', color: '#fff',
                              border: '1px solid #444', borderRadius: '3px',
                              fontSize: '0.85em',
                            }}
                            value={selectedJumpDestination || ''}
                            onChange={(e) => setSelectedJumpDestination(e.target.value)}
                          >
                            <option value="">-- Select System --</option>
                            {jumpDestinations.map((dest) => (
                              <option key={dest.id} value={dest.id}>{dest.name}</option>
                            ))}
                          </select>
                          {selectedJumpDestination && (
                            <Box fontSize="0.8em" color="gray" italic mt={0.5}>
                              {jumpDestinations.find(d => d.id === selectedJumpDestination)?.description}
                            </Box>
                          )}
                          <Button
                            fluid
                            icon="rocket"
                            color="purple"
                            mt={0.5}
                            disabled={!selectedJumpDestination}
                            onClick={() => {
                              if (selectedJumpDestination) {
                                act('jump', { systemId: selectedJumpDestination });
                                setSelectedJumpDestination(null);
                              }
                            }}
                          >
                            Initiate Jump
                          </Button>
                        </>
                      )}
                    </Box>
                  )}
                </>
              )}
            </Section>
          </Flex.Item>
        </Flex>
      </Window.Content>
    </Window>
  );
};
