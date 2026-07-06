import { useRef, useState, useEffect } from 'react';
import { Box, Flex, Button } from 'tgui-core/components';

const holoPanelStyle = {
  backgroundColor: 'rgba(10, 20, 40, 0.7)',
  border: '1px solid rgba(0, 255, 255, 0.2)',
  boxShadow: 'inset 0 0 10px rgba(0, 255, 255, 0.1)',
  padding: '12px 8px',
  position: 'relative' as const,
};

const controlButtonStyle = (isActive: boolean) => ({
  backgroundColor: isActive ? 'rgba(0, 255, 255, 0.2)' : 'rgba(20, 30, 50, 0.8)',
  border: `1px solid ${isActive ? '#00ffff' : '#2a4a6a'}`,
  color: isActive ? '#ffffff' : '#88ddff',
  boxShadow: isActive ? '0 0 8px rgba(0, 255, 255, 0.6)' : 'none',
  transition: 'all 0.1s ease',
  width: '34px',
  height: '34px',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  cursor: 'pointer',
  userSelect: 'none' as const,
  borderRadius: '4px',
  fontSize: '1.1em',
});

// Специальный стиль для кнопки STOP (в центре)
const stopButtonStyle = {
  backgroundColor: 'rgba(50, 20, 20, 0.8)',
  border: '1px solid #aa2a2a',
  color: '#ff3333',
  boxShadow: 'none',
  transition: 'all 0.1s ease',
  width: '34px',
  height: '34px',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  cursor: 'pointer',
  userSelect: 'none' as const,
  borderRadius: '4px',
  fontSize: '0.7em',
  fontWeight: 'bold',
};

export const FlightControls = (props) => {
  const { isDocked, shuttleAngle, shuttlePitch, shuttleThrust, act, activeKeys } = props;
  const sliderRef = useRef<HTMLDivElement>(null);
  const [isDragging, setIsDragging] = useState(false);

  const applyThrustFromEvent = (e: MouseEvent | React.MouseEvent) => {
    if (!sliderRef.current || isDocked) return;
    const rect = sliderRef.current.getBoundingClientRect();
    const percent = Math.round(((e.clientX - rect.left) / rect.width) * 100);
    const clampedPercent = Math.max(0, Math.min(100, percent));

    act('set_thrust', {
      angle: shuttleAngle,
      power: clampedPercent,
      pitch: shuttlePitch || 0
    });
  };

  useEffect(() => {
    if (!isDragging) return;

    const handleMouseMove = (e: MouseEvent) => applyThrustFromEvent(e);
    const handleMouseUp = () => setIsDragging(false);

    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseup', handleMouseUp);

    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleMouseUp);
    };
  }, [isDragging, isDocked, shuttleAngle, shuttlePitch, act]);

  const getThrustColor = (power: number) => {
    if (power < 33) return '#33ff33';
    if (power < 66) return '#ffaa00';
    return '#ff3333';
  };

   return (
    <Box mb={1} style={holoPanelStyle}>
      {/* === КНОПКА В УГЛУ ПАНЕЛИ === */}
      <Button
        compact
        icon="circle-info"
        color="transparent"
        tooltip={
          <Box fontFamily="monospace" fontSize="0.9em">
            <Box mb={0.5} bold color="cyan">УПРАВЛЕНИЕ</Box>
            <Box>W A S D — Повороты корпуса</Box>
            <Box>Q / E — Тяга (- / +)</Box>
            <Box>X — Сброс тяги</Box>
            <Box mt={0.5} bold color="cyan">НАВИГАЦИЯ</Box>
            <Box>ПКМ — Задать курс (Автопилот)</Box>
            <Box>Ctrl + ПКМ — Регулировка высоты</Box>
            <Box>Shift + ПКМ — Отменить курс</Box>
          </Box>
        }
        tooltipPosition="bottom-end"
        style={{ position: 'absolute', top: '4px', right: '4px', zIndex: 2 }}
      />

      <Flex direction="column" align="center" gap={1}>
        {/* --- ЕДИНЫЙ БЛОК УПРАВЛЕНИЯ (D-PAD + ТЯГА) --- */}
        <Flex direction="column" align="center" gap={2}>
          <Box fontSize="0.7em" color="#88ddff" mb={0.5} letterSpacing="2px">FLIGHT CONTROL</Box>

          {/* Ряд 1: [-], [W], [+] */}
          <Flex gap={2} align="center">
            <div
              style={{ ...controlButtonStyle(false), width: '30px', height: '30px', color: '#ffaa00', fontSize: '1.2em' }}
              onClick={() => !isDocked && act('set_thrust', { angle: shuttleAngle, power: Math.max(shuttleThrust - 10, 0), pitch: shuttlePitch || 0 })}
            >−</div>
            <div
              style={controlButtonStyle(activeKeys['w'] || activeKeys['ц'])}
              onMouseDown={() => !isDocked && act('toggle_rotate_pitch_up', { enable: true })}
              onMouseUp={() => !isDocked && act('toggle_rotate_pitch_up', { enable: false })}
              onMouseLeave={() => !isDocked && act('toggle_rotate_pitch_up', { enable: false })}
            >↑</div>
            <div
              style={{ ...controlButtonStyle(false), width: '30px', height: '30px', color: '#33ff33', fontSize: '1.2em' }}
              onClick={() => !isDocked && act('set_thrust', { angle: shuttleAngle, power: Math.min(shuttleThrust + 10, 100), pitch: shuttlePitch || 0 })}
            >+</div>
          </Flex>

          {/* Ряд 2: [A], [STOP], [D] */}
          <Flex gap={2} align="center">
            <div
              style={controlButtonStyle(activeKeys['a'] || activeKeys['ф'])}
              onMouseDown={() => !isDocked && act('toggle_rotate_left', { enable: true })}
              onMouseUp={() => !isDocked && act('toggle_rotate_left', { enable: false })}
              onMouseLeave={() => !isDocked && act('toggle_rotate_left', { enable: false })}
            >←</div>
            <div
              style={{ ...stopButtonStyle, width: '30px', height: '30px', fontSize: '0.6em' }}
              onClick={() => !isDocked && act('kill_thrust')}
            >STOP</div>
            <div
              style={controlButtonStyle(activeKeys['d'] || activeKeys['в'])}
              onMouseDown={() => !isDocked && act('toggle_rotate_right', { enable: true })}
              onMouseUp={() => !isDocked && act('toggle_rotate_right', { enable: false })}
              onMouseLeave={() => !isDocked && act('toggle_rotate_right', { enable: false })}
            >→</div>
          </Flex>

          {/* Ряд 3: Пусто, [S], Пусто (для симметрии) */}
          <Flex gap={2}>
            <div style={{ width: '34px', height: '34px' }} />
            <div
              style={controlButtonStyle(activeKeys['s'] || activeKeys['ы'])}
              onMouseDown={() => !isDocked && act('toggle_rotate_pitch_down', { enable: true })}
              onMouseUp={() => !isDocked && act('toggle_rotate_pitch_down', { enable: false })}
              onMouseLeave={() => !isDocked && act('toggle_rotate_pitch_down', { enable: false })}
            >↓</div>
            <div style={{ width: '34px', height: '34px' }} />
          </Flex>
        </Flex>

        {/* --- ШКАЛА ТЯГИ --- */}
        <Box width="100%" mt={1}>
          <Flex justify="space-between" mb={0.5}>
            <Box fontSize="0.7em" color="#88ddff" letterSpacing="2px">THRUST</Box>
            <Box fontSize="0.8em" color={getThrustColor(shuttleThrust)} bold>
              {shuttleThrust.toFixed(0)}%
            </Box>
          </Flex>

          <div
            ref={sliderRef}
            onMouseDown={(e) => {
              if (!isDocked) {
                setIsDragging(true);
                applyThrustFromEvent(e);
              }
            }}
            style={{
              width: '100%',
              height: '16px',
              backgroundColor: 'rgba(0, 0, 0, 0.6)',
              border: '1px solid #2a4a6a',
              cursor: 'pointer',
              position: 'relative',
              overflow: 'hidden',
            }}
          >
            <div style={{
              width: `${shuttleThrust}%`,
              height: '100%',
              backgroundColor: getThrustColor(shuttleThrust),
              boxShadow: `0 0 8px ${getThrustColor(shuttleThrust)}`,
              transition: 'width 0.1s ease-out',
              pointerEvents: 'none'
            }} />

            <Flex style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%', pointerEvents: 'none' }}>
              {Array.from({ length: 10 }).map((_, i) => (
                <Box key={i} style={{ flex: 1, borderRight: i < 9 ? '1px solid rgba(0, 0, 0, 0.5)' : 'none' }} />
              ))}
            </Flex>
          </div>
        </Box>

      </Flex>
    </Box>
  );
};
