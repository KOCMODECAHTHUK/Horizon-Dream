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
  autopilot_enabled?: boolean;
  hasPendingTarget?: boolean;
  pendingTargetX?: number;
  pendingTargetY?: number;
  pendingTargetZ?: number;
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
  hasPendingTarget: boolean;
  pendingTargetX: number | null;
  pendingTargetY: number | null;
  pendingTargetZ: number | null;
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
    hasPendingTarget = false,
    pendingTargetX = null,
    pendingTargetY = null,
    pendingTargetZ = null,
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

  const [cameraYaw, setCameraYaw] = useState(45);
  const [cameraPitch, setCameraPitch] = useState(30);
  const [zoomScale, setZoomScale] = useState(1);
  const [selectedJumpDestination, setSelectedJumpDestination] = useState<string | null>(null);
  const [actionError, setActionError] = useState('');

  useEffect(() => {
    if (lastActionError) {
      setActionError(lastActionError);
      const timer = setTimeout(() => setActionError(''), 3000);
      return () => clearTimeout(timer);
    }
  }, [lastActionError, update_index]);

  const ourPos = ourObject
    ? (ourObject.position || [ourObject.position_x || 0, ourObject.position_y || 0, ourObject.position_z || 0])
    : [0, 0, 0];

  const focusX = linkedToShuttle ? ourPos[0] : 0;
  const focusY = linkedToShuttle ? ourPos[1] : 0;
  const focusZ = linkedToShuttle ? ourPos[2] : 0;

  // Keyboard controls: WASD = Rotate, Q = Thrust -, E = Thrust +
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (!linkedToShuttle || isDocked) return;
      if (document.activeElement && ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement.tagName)) return;

      switch (event.key.toLowerCase()) {
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
        case 'q':
          event.preventDefault();
          act('set_thrust', { angle: shuttleAngle, power: Math.max(shuttleThrust - 10, 0), pitch: shuttlePitch || 0 });
          break;
        case 'e':
          event.preventDefault();
          act('set_thrust', { angle: shuttleAngle, power: Math.min(shuttleThrust + 10, 100), pitch: shuttlePitch || 0 });
          break;
        case 'x':
          event.preventDefault();
          act('kill_thrust');
          break;
      }
    };

    const handleKeyUp = (event: KeyboardEvent) => {
      if (!linkedToShuttle || isDocked) return;

      switch (event.key.toLowerCase()) {
        case 'w':
        case 'ц':
          act('toggle_rotate_pitch_up', { enable: false });
          break;
        case 's':
        case 'ы':
          act('toggle_rotate_pitch_down', { enable: false });
          break;
        case 'a':
        case 'ф':
          act('toggle_rotate_left', { enable: false });
          break;
        case 'd':
        case 'в':
          act('toggle_rotate_right', { enable: false });
          break;
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
    };
  }, [linkedToShuttle, isDocked, act, shuttleAngle, shuttlePitch, shuttleThrust]);

  const clampPitch = (value: number) => Math.max(5, Math.min(85, value));

  const rotateCamera = useCallback((dyaw: number, dpitch: number) => {
    setCameraYaw((prev) => (prev + dyaw + 360) % 360);
    setCameraPitch((prev) => clampPitch(prev + dpitch));
  }, []);

  const handleZoom = useCallback((factor: number) => {
    setZoomScale((prev) => Math.max(0.1, Math.min(10, prev * factor)));
  }, []);

  const canvasMapObjects = map_objects.map((obj) => {
    const pos = obj.position && Array.isArray(obj.position)
      ? obj.position : [obj.position_x || 0, obj.position_y || 0, obj.position_z || 0];
    const vel = obj.velocity && Array.isArray(obj.velocity)
      ? obj.velocity : [obj.velocity_x || 0, obj.velocity_y || 0, obj.velocity_z || 0];
    return { ...obj, position_x: pos[0], position_y: pos[1], position_z: pos[2] || 0, velocity_x: vel[0], velocity_y: vel[1], velocity_z: vel[2] || 0 };
  });

  const ourObjectNormalized = ourObject ? {
    ...ourObject,
    position: ourObject.position || [ourObject.position_x || 0, ourObject.position_y || 0, ourObject.position_z || 0],
    velocity: ourObject.velocity || [ourObject.velocity_x || 0, ourObject.velocity_y || 0, ourObject.velocity_z || 0],
  } : null;

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
                pendingTargetX={pendingTargetX}
                pendingTargetY={pendingTargetY}
                pendingTargetZ={pendingTargetZ}
                hasPendingTarget={hasPendingTarget}
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
                onMapClick={(worldX, worldY, clickType, altKey, objectId, targetZ) => {
                  if (isDocked) return;

                  if (clickType === 'cancel') {
                    act('clearPendingTarget');
                    return;
                  }

                  if (clickType === 'right') {
                    const finalZ = targetZ != null ? targetZ : (ourPos[2] || 0);
                    if (altKey) {
                      act('setTargetCoords', { x: worldX, y: worldY, z: finalZ, altKey: true });
                    } else {
                      act('setTargetCoords', { x: worldX, y: worldY, z: finalZ });
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
                    <NoticeBox color="red" mb={0.5} fontSize="0.8em">{actionError}</NoticeBox>
                  )}
                  <Box bold mb={0.5} fontSize="1em" color="cyan">{shuttleName}</Box>
                  <Box mb={0.5} fontSize="0.8em" color="label">
                    POS {ourPos[0]?.toFixed(0)},{ourPos[1]?.toFixed(0)},Z{ourPos[2]?.toFixed(0)}
                  </Box>

                  <Box mb={0.5}>
                    <Flex wrap="wrap" gap={0.5} mb={0.5}>
                      <Box bold fontSize="0.75em" color="label" style={{ width: '100%' }}>Rotation (W A S D):</Box>
                      <Button compact icon="rotate-left" color="yellow" disabled={isDocked}
                        onMouseDown={() => act('toggle_rotate_left', { enable: true })}
                        onMouseUp={() => act('toggle_rotate_left', { enable: false })}
                        onMouseLeave={() => act('toggle_rotate_left', { enable: false })}
                        tooltip="Rotate left (A)">←</Button>
                      <Button compact icon="rotate-right" color="yellow" disabled={isDocked}
                        onMouseDown={() => act('toggle_rotate_right', { enable: true })}
                        onMouseUp={() => act('toggle_rotate_right', { enable: false })}
                        onMouseLeave={() => act('toggle_rotate_right', { enable: false })}
                        tooltip="Rotate right (D)">→</Button>
                      <Button compact icon="angle-double-up" color="yellow" disabled={isDocked}
                        onMouseDown={() => act('toggle_rotate_pitch_up', { enable: true })}
                        onMouseUp={() => act('toggle_rotate_pitch_up', { enable: false })}
                        onMouseLeave={() => act('toggle_rotate_pitch_up', { enable: false })}
                        tooltip="Pitch up (W)">↑</Button>
                      <Button compact icon="angle-double-down" color="yellow" disabled={isDocked}
                        onMouseDown={() => act('toggle_rotate_pitch_down', { enable: true })}
                        onMouseUp={() => act('toggle_rotate_pitch_down', { enable: false })}
                        onMouseLeave={() => act('toggle_rotate_pitch_down', { enable: false })}
                        tooltip="Pitch down (S)">↓</Button>
                    </Flex>
                    <Flex wrap="wrap" gap={0.5}>
                      <Button compact icon="arrow-down" disabled={isDocked}
                        onClick={() => act('set_thrust', { angle: shuttleAngle, power: Math.max(shuttleThrust - 10, 0), pitch: shuttlePitch || 0 })}
                        tooltip="Thrust -10% (Q)">-Pwr</Button>
                      <Button compact icon="arrow-up" disabled={isDocked}
                        onClick={() => act('set_thrust', { angle: shuttleAngle, power: Math.min(shuttleThrust + 10, 100), pitch: shuttlePitch || 0 })}
                        tooltip="Thrust +10% (E)">+Pwr</Button>
                      <Button compact icon="arrow-up" color="teal" disabled={isDocked}
                        onClick={() => act('adjust_altitude', { dz: 10 })}
                        tooltip="Ascend">↑Alt</Button>
                      <Button compact icon="arrow-down" color="teal" disabled={isDocked}
                        onClick={() => act('adjust_altitude', { dz: -10 })}
                        tooltip="Descend">↓Alt</Button>
                      <Button fluid compact icon="xmark" color="red" disabled={isDocked}
                        onClick={() => act('kill_thrust')}
                        tooltip="Kill Thrust (X)">STOP</Button>
                    </Flex>
                  </Box>

                  <Flex mb={0.5}>
                    <Button compact icon="search-plus" onClick={() => handleZoom(1.3)} tooltip="Zoom In" />
                    <Button compact icon="search-minus" onClick={() => handleZoom(0.7)} tooltip="Zoom Out" />
                    <Box as="span" ml={1} fontSize="0.8em" color="label" lineHeight="22px">
                      Zoom: {zoomScale.toFixed(1)}x
                    </Box>
                  </Flex>

                  {isDocked ? (
                    <NoticeBox color="red" fontSize="0.8em" mt={0.5}>DOCKED — {dockedStation}</NoticeBox>
                  ) : hasPendingTarget ? (
                    <NoticeBox color="yellow" fontSize="0.8em" mt={0.5}>
                      <Box mb={0.5}>AUTOPILOT TARGET: ({pendingTargetX?.toFixed(0)}, {pendingTargetY?.toFixed(0)}, Z{(pendingTargetZ || 0).toFixed(0)})</Box>
                      <Flex gap={0.5}>
                        <Button compact icon="check" color="green" onClick={() => act('confirmAutopilot')}>Confirm</Button>
                        <Button compact icon="xmark" color="red" onClick={() => act('clearPendingTarget')}>Cancel</Button>
                      </Flex>
                    </NoticeBox>
                  ) : autopilotEnabled ? (
                    <NoticeBox color="green" fontSize="0.8em" mt={0.5}>
                      AUTOPILOT → ({targetX?.toFixed(0)}, {targetY?.toFixed(0)}, Z{(targetZ || 0).toFixed(0)})
                      <Button fluid compact icon="xmark" color="red" mt={0.5} onClick={() => act('clearPendingTarget')}>Cancel Autopilot</Button>
                    </NoticeBox>
                  ) : (
                    <NoticeBox color="purple" fontSize="0.8em" mt={0.5}>Right-click map → set course</NoticeBox>
                  )}

                  {isDocked && (
                    <Button fluid icon="anchor" color="red" mt={0.5} onClick={() => act('undock')}>Undock</Button>
                  )}

                  {!isDocked && nearbyObjects?.length > 0 && (
                    <Box mt={0.5}>
                      <Box bold fontSize="0.8em" color="label">Contacts:</Box>
                      {nearbyObjects.map((obj) => (
                        <Flex key={obj.id} align="center" justify="space-between" mb={0.25}>
                          <Box fontSize="0.8em">
                            <Box as="span" color={obj.type === 'station' ? 'blue' : obj.type === 'planet' ? 'green' : 'gray'}>●</Box>{' '}
                            {obj.name}
                            <Box as="span" color="label" ml={1}>{obj.distance}km</Box>
                          </Box>
                          {obj.type === 'station' && (
                            <Button compact fontSize="0.75em" icon="anchor" disabled={obj.occupied || obj.distance > 20}
                              onClick={() => act('dock', { stationId: obj.id })}>
                              {obj.occupied ? 'Occupied' : obj.distance > 20 ? 'Too far' : 'Dock'}
                            </Button>
                          )}
                        </Flex>
                      ))}
                    </Box>
                  )}

                  {hasJumpDrive && (
                    <Box mt={0.5}>
                      <Box bold fontSize="0.8em" color="label">Jump Drive: {currentSystemName}</Box>
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
                            <select style={{ width: '100%', padding: '2px', backgroundColor: '#1a1a2e', color: '#fff', border: '1px solid #444', borderRadius: '2px', fontSize: '0.8em' }}
                              value={selectedJumpDestination || ''} onChange={(e) => setSelectedJumpDestination(e.target.value)}>
                              <option value="">-- System --</option>
                              {jumpDestinations.map((dest) => (<option key={dest.id} value={dest.id}>{dest.name}</option>))}
                            </select>
                          </Flex.Item>
                          <Flex.Item ml={0.5}>
                            <Button compact icon="rocket" color="purple" disabled={!selectedJumpDestination}
                              onClick={() => { if (selectedJumpDestination) { act('jump', { systemId: selectedJumpDestination }); setSelectedJumpDestination(null); } }}>
                              Jump
                            </Button>
                          </Flex.Item>
                        </Flex>
                      )}
                    </Box>
                  )}

                  <Box mt={1} fontSize="0.7em" color="dim">
                    W A S D — Повороты корпуса<br />
                    Q — Уменьшить тягу / E — Увеличить тягу<br />
                    X — Убить тягу<br />
                    ПКМ=курс · Ctrl+ПКМ=Z · Shift+ПКМ=отмена<br />
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
