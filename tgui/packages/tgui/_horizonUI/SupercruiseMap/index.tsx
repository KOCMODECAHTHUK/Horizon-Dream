import { useEffect, useState } from 'react';
import { useBackend } from '../../backend';
import { Box, Button, Flex, NoticeBox, Section } from 'tgui-core/components';
import { Window } from '../../layouts';
import { SupercruiseMapCanvas } from './components/MapCanvas';
import { FlightControls } from './screens/FlightControls';
import { NavigationStatus } from './screens/NavigationStatus';
import { NearbyContacts } from './screens/NearbyContacts';
import { JumpDrivePanel } from './screens/JumpDrivePanel';
import { useShuttleControls } from './ShuttleControls';

export const SupercruiseMap = () => {
  const { act, data } = useBackend();
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
    nearbyObjects = [],
    hasJumpDrive = false,
    isJumping = false,
    jumpReady = true,
    jumpCooldownRemaining = 0,
    jumpDestinations = [],
    currentSystemName = 'Unknown',
    lastActionError = '',
  } = data;

  const [selectedJumpDestination, setSelectedJumpDestination] = useState(null);
  const [actionError, setActionError] = useState('');

  useEffect(() => {
    if (lastActionError) {
      setActionError(lastActionError);
      const timer = setTimeout(() => setActionError(''), 3000);
      return () => clearTimeout(timer);
    }
  }, [lastActionError, update_index]);

  const { cameraYaw, cameraPitch, zoomScale, rotateCamera, handleZoom } = useShuttleControls(act, linkedToShuttle, isDocked, shuttleAngle, shuttlePitch, shuttleThrust);
  const ourPos = ourObject?.position ? [ourObject.position[0] || 0, ourObject.position[1] || 0, ourObject.position[2] || 0] : [0, 0, 0];
  const focusX = linkedToShuttle ? ourPos[0] : 0;
  const focusY = linkedToShuttle ? ourPos[1] : 0;
  const focusZ = linkedToShuttle ? ourPos[2] : 0;

  const canvasMapObjects = map_objects.map((obj) => ({
    ...obj,
    position_x: obj.position?.[0] ?? obj.position_x ?? 0,
    position_y: obj.position?.[1] ?? obj.position_y ?? 0,
    position_z: obj.position?.[2] ?? obj.position_z ?? 0,
    velocity_x: obj.velocity?.[0] ?? obj.velocity_x ?? 0,
    velocity_y: obj.velocity?.[1] ?? obj.velocity_y ?? 0,
    velocity_z: obj.velocity?.[2] ?? obj.velocity_z ?? 0,
  }));

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
                ourObject={ourObject}
                targetX={targetX} targetY={targetY} targetZ={targetZ}
                pendingTargetX={pendingTargetX} pendingTargetY={pendingTargetY} pendingTargetZ={pendingTargetZ}
                hasPendingTarget={hasPendingTarget}
                isDocked={isDocked}
                autopilotEnabled={autopilotEnabled}
                cameraYaw={cameraYaw} cameraPitch={cameraPitch} cameraDistance={600}
                focusX={focusX} focusY={focusY} focusZ={focusZ}
                shuttleVelX={shuttleVelX} shuttleVelY={shuttleVelY} shuttleVelZ={shuttleVelZ}
                shuttleAlt={ourPos[2] || 0}
                onRotate={rotateCamera}
                onZoom={handleZoom}
                onMapClick={(worldX, worldY, clickType, altKey, objectId, clickZ) => {
                  if (isDocked) return;
                  switch (clickType) {
                    case 'cancel':
                      act('clearPendingTarget');
                      break;
                    case 'right': {
                      const finalZ = clickZ != null ? clickZ : (ourPos[2] || 0);
                      act('setTargetCoords', { x: worldX, y: worldY, z: finalZ, altKey });
                      break;
                    }
                    case 'double':
                      if (objectId) act('dock', { stationId: objectId });
                      break;
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
                  {actionError && <NoticeBox color="red" mb={0.5} fontSize="0.8em">{actionError}</NoticeBox>}
                  <Box bold mb={0.5} fontSize="1em" color="cyan">{shuttleName}</Box>
                  <Box mb={0.5} fontSize="0.8em" color="label">
                    POS {ourPos[0]?.toFixed(0)},{ourPos[1]?.toFixed(0)},{ourPos[2]?.toFixed(0)}
                  </Box>

                  <FlightControls
                    isDocked={isDocked}
                    shuttleAngle={shuttleAngle}
                    shuttlePitch={shuttlePitch}
                    shuttleThrust={shuttleThrust}
                    act={act}
                  />

                  <Flex mb={0.5}>
                    <Button compact icon="search-plus" onClick={() => handleZoom(1.3)} tooltip="Zoom In" />
                    <Button compact icon="search-minus" onClick={() => handleZoom(0.7)} tooltip="Zoom Out" />
                    <Box as="span" ml={1} fontSize="0.8em" color="label" lineHeight="22px">
                      Zoom: {zoomScale.toFixed(1)}x
                    </Box>
                  </Flex>

                  <NavigationStatus
                    isDocked={isDocked}
                    dockedStation={dockedStation}
                    hasPendingTarget={hasPendingTarget}
                    pendingTargetX={pendingTargetX}
                    pendingTargetY={pendingTargetY}
                    pendingTargetZ={pendingTargetZ}
                    autopilotEnabled={autopilotEnabled}
                    targetX={targetX}
                    targetY={targetY}
                    targetZ={targetZ}
                    act={act}
                  />

                  {isDocked && (
                    <Button fluid icon="anchor" color="red" mt={0.5} onClick={() => act('undock')}>Undock</Button>
                  )}

                  {!isDocked && (
                    <NearbyContacts nearbyObjects={nearbyObjects} act={act} />
                  )}

                  <JumpDrivePanel
                    hasJumpDrive={hasJumpDrive}
                    currentSystemName={currentSystemName}
                    isJumping={isJumping}
                    jumpReady={jumpReady}
                    isDocked={isDocked}
                    jumpDestinations={jumpDestinations}
                    jumpCooldownRemaining={jumpCooldownRemaining}
                    selectedJumpDestination={selectedJumpDestination}
                    setSelectedJumpDestination={setSelectedJumpDestination}
                    act={act}
                  />

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
