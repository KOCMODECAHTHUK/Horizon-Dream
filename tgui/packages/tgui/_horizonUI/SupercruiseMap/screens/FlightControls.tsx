import { Box, Button, Flex } from 'tgui-core/components';

export const FlightControls = (props) => {
  const { isDocked, shuttleAngle, shuttlePitch, shuttleThrust, act } = props;

  return (
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
  );
};
