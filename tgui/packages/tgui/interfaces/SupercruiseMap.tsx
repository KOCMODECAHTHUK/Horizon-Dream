import { useEffect, useState } from 'react';

import { useBackend } from '../backend';
import { Box, Button, Flex, NoticeBox, Section } from 'tgui-core/components';
import { Window } from '../layouts';
import { SupercruiseMapSvg } from '../components/SupercruiseMapSvg';

interface MapObject {
  id: string;
  name: string;
  position_x: number;
  position_y: number;
  position_z: number;
  velocity_x: number;
  velocity_y: number;
  velocity_z: number;
  radius: number;
  render_mode: string;
  vel_mult: number;
  priority: number;
  supercruise_color: string;
  system_id?: string;
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
  shuttleThrust: number;
  shuttleVelX: number;
  shuttleVelY: number;
  shuttleVelZ: number;
  shuttleAlt: number;
  update_index: number;
  ourObject: MapObject | null;
  autopilotEnabled: boolean;
  targetX: number | null;
  targetY: number | null;
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
 * Hey folks I am not good with tgui this was made with the help of some AI shit
 * so please like yell at me if anything looks like dogshit
 */
export const SupercruiseMap = (props) => {
  const { act, data } = useBackend<SupercruiseMapData>();
  const {
    map_objects = [],
    linkedToShuttle = false,
    shuttleName = '',
    shuttleAngle = 0,
    shuttleThrust = 0,
    shuttleVelX = 0,
    shuttleVelY = 0,
    shuttleVelZ = 0,
    shuttleAlt = 0,
    update_index = 0,
    ourObject = null,
    autopilotEnabled = false,
    targetX = null,
    targetY = null,
    isDocked = false,
    dockedStation = null,
    nearbyStations = [],
    nearbyObjects = [],
    hasJumpDrive = false,
    isJumping = false,
    jumpCooldown = 60,
    jumpReady = true,
    jumpCooldownRemaining = 0,
    jumpDestinations = [],
    currentSystemName = 'Unknown',
  } = data;

  const [zoomScale, setZoomScale] = useState(1);
  const [cameraYaw, setCameraYaw] = useState(45);
  const [cameraPitch, setCameraPitch] = useState(20);
  const [selectedJumpDestination, setSelectedJumpDestination] = useState<string | null>(null);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (!linkedToShuttle || isDocked) return;
      if (document.activeElement && ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement.tagName)) return;

      let dz = 0;
      if (event.key === 'q' || event.key === 'Q' || event.key === ' ' || event.key === 'Spacebar') {
        dz = 10;
      } else if (event.key === 'e' || event.key === 'E' || event.key.toLowerCase() === 'c') {
        dz = -10;
      }

      if (dz !== 0) {
        event.preventDefault();
        act('adjust_altitude', { dz });
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [linkedToShuttle, isDocked, act]);

  const clampPitch = (value: number) => Math.max(10, Math.min(80, value));
  const rotateCamera = (dyaw: number, dpitch: number) => {
    setCameraYaw((prev) => (prev + dyaw + 360) % 360);
    setCameraPitch((prev) => clampPitch(prev + dpitch));
  };

  // Calculate velocity angle and speed
  const velocitySpeed = Math.sqrt(shuttleVelX * shuttleVelX + shuttleVelY * shuttleVelY);
  const velocity3D = Math.sqrt(shuttleVelX * shuttleVelX + shuttleVelY * shuttleVelY + shuttleVelZ * shuttleVelZ);
  const velocityAngle = velocitySpeed > 0.01
    ? (Math.atan2(shuttleVelY, shuttleVelX) * 180 / Math.PI + 360) % 360
    : 0;

  // Auto-center camera on our shuttle
  const xOffset = linkedToShuttle && ourObject ? -ourObject.position_x : 0;
  const yOffset = linkedToShuttle && ourObject ? -ourObject.position_y : 0;

  return (
    <Window width={1000} height={700}>
      <Window.Content>
        <Flex height="100%">
          <Flex.Item grow>
            <Box position="relative" height="100%" backgroundColor="#0a0a1a">
              {/* Map display */}
              <SupercruiseMapSvg
                map_objects={map_objects}
                update_index={update_index}
                xOffset={xOffset}
                yOffset={yOffset}
                zoomScale={zoomScale}
                shuttleAngle={shuttleAngle}
                shuttleThrust={shuttleThrust}
                ourObject={ourObject}
                targetX={targetX}
                targetY={targetY}
                isDocked={isDocked}
                autopilotEnabled={autopilotEnabled}
                cameraYaw={cameraYaw}
                cameraPitch={cameraPitch}
                onRotate={rotateCamera}
                onMapClick={(worldX, worldY, clickType, altKey) => {
                  if (isDocked || clickType !== 'right') return;
                  act('setTargetCoords', {
                    x: worldX,
                    y: worldY,
                    altKey: altKey,
                  });
                }}
              />
            </Box>
          </Flex.Item>

          <Flex.Item width="300px">
            <Section title="Flight Controls" height="100%">
              {/* Zoom controls - moved here to avoid blocking map clicks */}
              <Flex mb={2}>
                <Flex.Item grow>
                  <Box bold>Zoom</Box>
                </Flex.Item>
                <Flex.Item>
                  <Button
                    compact
                    icon="search-plus"
                    tooltip="Zoom In"
                    onClick={() => setZoomScale(zoomScale * 1.5)}
                  />
                  <Button
                    compact
                    icon="search-minus"
                    tooltip="Zoom Out"
                    onClick={() => setZoomScale(zoomScale / 1.5)}
                  />
                </Flex.Item>
              </Flex>

              {!linkedToShuttle ? (
                <NoticeBox>No shuttle linked to console</NoticeBox>
              ) : (
                <>
                  <Box bold mb={1}>
                    {shuttleName}
                  </Box>

                  <Box mb={2}>
                    <Box>Coordinates: {ourObject?.position_x?.toFixed(1)}, {ourObject?.position_y?.toFixed(1)}, Z {ourObject?.position_z?.toFixed(1)}</Box>
                    <Box>Velocity: {shuttleVelX?.toFixed(2)}, {shuttleVelY?.toFixed(2)}, {shuttleVelZ?.toFixed(2)} km/s</Box>
                    <Box>3D Speed: {velocity3D.toFixed(2)} km/s</Box>
                    <Box color="cyan">Speed: {velocitySpeed.toFixed(2)} km/s @ {velocityAngle.toFixed(0)}°</Box>
                  </Box>

                  <Box bold mb={1}>
                    Altitude: {shuttleAlt.toFixed(1)} km ({shuttleAlt >= 0 ? 'Above' : 'Below'} plane)
                  </Box>
                  <Box mb={1}>
                    <div style={{ width: '100%', height: '10px', background: '#111', border: '1px solid #444', borderRadius: '4px', position: 'relative' }}>
                      <div style={{ position: 'absolute', left: '50%', top: 0, bottom: 0, width: '2px', background: '#555' }} />
                      <div style={{ position: 'absolute', left: `${50 + Math.max(-50, Math.min(50, shuttleAlt / 100 * 50))}%`, top: 0, bottom: 0, width: '4px', background: '#ff88ff', transform: 'translateX(-50%)' }} />
                    </div>
                  </Box>
                  <Flex mb={2}>
                    <Button
                      icon="arrow-up"
                      disabled={isDocked}
                      onClick={() => act('adjust_altitude', { dz: 10 })}
                    >
                      Ascend
                    </Button>
                    <Button
                      icon="arrow-down"
                      disabled={isDocked}
                      onClick={() => act('adjust_altitude', { dz: -10 })}
                    >
                      Descend
                    </Button>
                  </Flex>
                  <Box fontSize="0.85em" color="gray">
                    Q / Space = ascend, E / C = descend
                  </Box>

                  <Box bold mb={1}>
                    Thrust Angle: {shuttleAngle}°
                  </Box>
                  <Button
                    icon="plus"
                    disabled={isDocked}
                    onClick={() =>
                      act('set_thrust', {
                        angle: (shuttleAngle + 10) % 360,
                        power: shuttleThrust,
                      })
                    }
                  >
                    Rotate +10°
                  </Button>
                  <Button
                    icon="minus"
                    disabled={isDocked}
                    onClick={() =>
                      act('set_thrust', {
                        angle: (shuttleAngle - 10 + 360) % 360,
                        power: shuttleThrust,
                      })
                    }
                  >
                    Rotate -10°
                  </Button>

                  <Box bold mt={2} mb={1}>
                    Thrust Power: {shuttleThrust}%
                  </Box>
                  <Button
                    icon="arrow-up"
                    disabled={isDocked}
                    onClick={() =>
                      act('set_thrust', {
                        angle: shuttleAngle,
                        power: Math.min(shuttleThrust + 10, 100),
                      })
                    }
                  >
                    Increase
                  </Button>
                  <Button
                    icon="arrow-down"
                    disabled={isDocked}
                    onClick={() =>
                      act('set_thrust', {
                        angle: shuttleAngle,
                        power: Math.max(shuttleThrust - 10, 0),
                      })
                    }
                  >
                    Decrease
                  </Button>

                  <Box mt={3}>
                    {isDocked ? (
                      <NoticeBox color="red">
                        Flight controls locked - Undock to fly
                      </NoticeBox>
                    ) : (
                      <NoticeBox color={autopilotEnabled ? "green" : "purple"}>
                        {autopilotEnabled
                          ? `Autopilot ACTIVE - Flying to (${targetX?.toFixed(0)}, ${targetY?.toFixed(0)})`
                          : "Click in map to fly to location. Alt+Click to stop."}
                      </NoticeBox>
                    )}
                  </Box>

                  {/* Docking/Interaction Section */}
                  <Box mt={3}>
                    {isDocked ? (
                      <>
                        <NoticeBox color="teal">
                          Docked at {dockedStation}
                        </NoticeBox>
                        <Button
                          fluid
                          mt={1}
                          icon="anchor"
                          color="red"
                          onClick={() => act('undock')}
                        >
                          Undock
                        </Button>
                      </>
                    ) : nearbyObjects?.length > 0 ? (
                      <>
                        <Box bold mb={1}>
                          Nearby Objects:
                        </Box>
                        {nearbyObjects.map((obj) => (
                          <Box key={obj.id} mb={1}>
                            <Box>
                              {obj.name}
                              <Box
                                as="span"
                                ml={1}
                                fontSize="0.85em"
                                color={
                                  obj.type === 'station' ? 'blue' :
                                  obj.type === 'planet' ? 'green' :
                                  'gray'
                                }
                              >
                                [{obj.type}]
                              </Box>
                            </Box>
                            <Box fontSize="0.9em" color="gray">
                              {obj.distance}km away
                              {obj.occupied && " (Occupied)"}
                            </Box>
                            <Button
                              icon={obj.type === 'station' ? 'anchor' : 'hand-pointer'}
                              disabled={obj.occupied && obj.type === 'station'}
                              onClick={() =>
                                act('dock', { stationId: obj.id })
                              }
                            >
                              {obj.type === 'station' ? 'Request Docking' : 'Interact'}
                            </Button>
                          </Box>
                        ))}
                      </>
                    ) : (
                      <NoticeBox>
                        No interactable objects in range
                      </NoticeBox>
                    )}
                  </Box>

                  {/* Jump Drive Section */}
                  {hasJumpDrive && (
                    <Box mt={3}>
                      <Box bold mb={1}>
                        Jump Drive
                      </Box>
                      <Box mb={1} fontSize="0.9em" color="cyan">
                        Current System: {currentSystemName}
                      </Box>

                      {isJumping ? (
                        <NoticeBox color="orange">
                          Jump in progress...
                        </NoticeBox>
                      ) : !jumpReady ? (
                        <NoticeBox color="red">
                          Cooling down: {Math.ceil(jumpCooldownRemaining)}s remaining
                        </NoticeBox>
                      ) : isDocked ? (
                        <NoticeBox color="red">
                          Cannot jump while docked - Undock first
                        </NoticeBox>
                      ) : jumpDestinations.length === 0 ? (
                        <NoticeBox>
                          No jump destinations available from this system
                        </NoticeBox>
                      ) : (
                        <>
                          <Box mb={1}>
                            <Box fontSize="0.9em" mb={0.5}>
                              Select Destination:
                            </Box>
                            <select
                              style={{
                                width: '100%',
                                padding: '4px',
                                backgroundColor: '#1a1a2e',
                                color: '#ffffff',
                                border: '1px solid #444',
                                borderRadius: '3px',
                              }}
                              value={selectedJumpDestination || ''}
                              onChange={(e) => setSelectedJumpDestination(e.target.value)}
                            >
                              <option value="">-- Select System --</option>
                              {jumpDestinations.map((dest) => (
                                <option key={dest.id} value={dest.id}>
                                  {dest.name}
                                </option>
                              ))}
                            </select>
                          </Box>

                          {selectedJumpDestination && (
                            <Box mb={1} fontSize="0.85em" color="gray" italic>
                              {jumpDestinations.find(d => d.id === selectedJumpDestination)?.description}
                            </Box>
                          )}

                          <Button
                            fluid
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
