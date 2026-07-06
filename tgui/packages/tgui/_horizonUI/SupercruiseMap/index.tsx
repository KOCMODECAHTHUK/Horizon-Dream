import { useEffect, useState } from 'react';
import { useBackend } from '../../backend';
import { Box, Button, Flex, NoticeBox } from 'tgui-core/components';
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
  const [showPanel, setShowPanel] = useState(true);
  const [hoveredContactId, setHoveredContactId] = useState(null);

  useEffect(() => {
    if (lastActionError) {
      setActionError(lastActionError);
      const timer = setTimeout(() => setActionError(''), 3000);
      return () => clearTimeout(timer);
    }
  }, [lastActionError, update_index]);

  const { cameraYaw, cameraPitch, zoomScale, rotateCamera, handleZoom, activeKeys } = useShuttleControls(act, linkedToShuttle, isDocked, shuttleAngle, shuttlePitch, shuttleThrust);
  const ourPos = ourObject ? [ourObject.position_x || 0, ourObject.position_y || 0, ourObject.position_z || 0] : [0, 0, 0];
  const focusX = linkedToShuttle ? ourPos[0] : 0;
  const focusY = linkedToShuttle ? ourPos[1] : 0;
  const focusZ = linkedToShuttle ? ourPos[2] : 0;

  const canvasMapObjects = map_objects;

  return (
    <Window width={1100} height={750}>
      <Window.Content>
        <Flex height="100%">
          <Flex.Item grow>
            <Box position="relative" height="100%" backgroundColor="#0a0a1a">
              {/* === HTML СТАТУС АВТОПИЛОТА / ДОКИНГА === */}
              {(isDocked || autopilotEnabled || hasPendingTarget || '') && (
                <Box
                  position="absolute"
                  top="15px"
                  left="50%"
                  style={{
                    transform: 'translateX(-50%)',
                    zIndex: 10,
                    pointerEvents: 'none',
                    textShadow: `0 0 8px ${isDocked ? '#ff5050' : autopilotEnabled ? '#32ff32' : '#ffc800'}`,
                    fontWeight: 'bold',
                    letterSpacing: '1px',
                    backgroundColor: 'rgba(10, 15, 30, 0.85)',
                    border: `1px solid ${isDocked ? 'rgba(255, 80, 80, 0.5)' : autopilotEnabled ? 'rgba(50, 255, 50, 0.5)' : 'rgba(255, 200, 0, 0.5)'}`,
                    padding: '4px 32px',
                    fontFamily: 'monospace',
                    fontSize: '0.9em',
                    color: isDocked ? '#ff5050' : autopilotEnabled ? '#32ff32' : '#ffc800',
                  }}
                >
                  {isDocked ? 'DOCKED' : autopilotEnabled ? 'AUTOPILOT ENGAGED' : hasPendingTarget ? 'COURSE PENDING' : ''}
                </Box>
              )}

              {/* Кнопка сворачивания панели */}
              <Button
                icon={showPanel ? 'angle-double-right' : 'angle-double-left'}
                tooltip={showPanel ? 'Скрыть панель управления' : 'Показать панель управления'}
                style={{ position: 'absolute', top: '10px', right: '10px', zIndex: 10 }}
                color="primary"
                onClick={() => setShowPanel(!showPanel)}
              />
              <Flex style={{ position: 'absolute', top: '10px', right: '40px', zIndex: 10 }}>
                <Button compact icon="search-plus" onClick={() => handleZoom(1.3)} tooltip="Zoom In" />
                <Button compact icon="search-minus" onClick={() => handleZoom(0.7)} tooltip="Zoom Out" />
                <Box as="span" ml={1} fontSize="0.8em" color="label" lineHeight="22px">
                  Zoom: {zoomScale.toFixed(1)}x
                </Box>
              </Flex>

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
                highlightedObjectId={hoveredContactId}
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

          {showPanel && (
            <Flex.Item width="260px" style={{ overflowY: 'auto', maxHeight: '100%', backgroundColor: 'rgba(5, 10, 20, 0.9)', borderLeft: '1px solid rgba(0, 255, 255, 0.1)' }}>
              <Box p={1}>
                {!linkedToShuttle ? (
                  <NoticeBox>No shuttle linked</NoticeBox>
                ) : (
                  <>
                    {actionError && <NoticeBox color="red" mb={0.5} fontSize="0.8em">{actionError}</NoticeBox>}
                    <Box mb={1} style={{
                      backgroundColor: 'rgba(10, 20, 40, 0.7)',
                      border: '1px solid rgba(0, 255, 255, 0.2)',
                      borderRadius: '0px',
                      boxShadow: 'inset 0 0 10px rgba(0, 255, 255, 0.1)',
                      padding: '8px 12px',
                    }}>
                      <Box bold fontSize="1.3em" color="cyan" mb={0.5} style={{ textShadow: '0 0 5px rgba(0, 255, 255, 0.5)' }}>{shuttleName}</Box>
                      <Box fontSize="0.8em" color="#88ddff" fontFamily="monospace" letterSpacing="1px" bold mb={0.5}>◉ Venture-Class</Box>
                      <Box fontFamily="monospace" fontSize="0.75em" color="label">
                        X: {ourPos[0]?.toFixed(0)} | Y: {ourPos[1]?.toFixed(0)} | Z: {ourPos[2]?.toFixed(0)}
                      </Box>
                    </Box>

                    <FlightControls
                      isDocked={isDocked}
                      shuttleAngle={shuttleAngle}
                      shuttlePitch={shuttlePitch}
                      shuttleThrust={shuttleThrust}
                      act={act}
                      activeKeys={activeKeys}
                    />

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

                    {!isDocked && (
                      <NearbyContacts nearbyObjects={nearbyObjects} act={act} onContactHover={setHoveredContactId}/>
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
                  </>
                )}
              </Box>
            </Flex.Item>
          )}
        </Flex>
      </Window.Content>
    </Window>
  );
};
