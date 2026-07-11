import { useState, useEffect, useCallback, useRef } from 'react';

export const useShuttleControls = (
  act: (action: string, payload?: any) => void,
  linkedToShuttle: boolean,
  isDocked: boolean,
  shuttleAngle: number,
  shuttlePitch: number,
  shuttleThrust: number
) => {
  const [cameraYaw, setCameraYaw] = useState(45);
  const [cameraPitch, setCameraPitch] = useState(30);
  const [zoomScale, setZoomScale] = useState(1);
  const [activeKeys, setActiveKeys] = useState<Record<string, boolean>>({});
  const keysRef = useRef<Record<string, boolean>>({});
  const rcsKeys = ['w', 's', 'a', 'd', 'ц', 'ы', 'ф', 'в', ' ', 'control'];

  // Хелпер: собирает и отправляет на сервер единый вектор стрейфа
  const calculateRcsVector = () => {
    let sx = 0, sy = 0, sz = 0;
    // Проверяем все возможные нажатия (if нужен, т.к. кнопки могут быть зажаты одновременно)
    if (keysRef.current['a'] || keysRef.current['ф']) sx -= 1;
    if (keysRef.current['d'] || keysRef.current['в']) sx += 1;
    if (keysRef.current[' ']) sy += 1; // Space = Up
    if (keysRef.current['control']) sy -= 1; // Ctrl = Down
    if (keysRef.current['w'] || keysRef.current['ц']) sz += 1;
    if (keysRef.current['s'] || keysRef.current['ы']) sz -= 1;

    if (sx === 0 && sy === 0 && sz === 0) {
      act('set_rcs', { sx: 0, sy: 0, sz: 0, power: 0 });
    } else {
      act('set_rcs', { sx, sy, sz, power: 10 });
    }
  };

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (!linkedToShuttle || isDocked) return;
      const target = document.activeElement;
      if (target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName)) return;
      const key = event.key.toLowerCase();
      if (keysRef.current[key]) return;
      keysRef.current[key] = true;
      setActiveKeys(prev => ({ ...prev, [key]: true }));

      // === РЕЖИМ RCS (Стрейф) ===
      if (keysRef.current['shift']) {
        if (rcsKeys.includes(key)) {
          event.preventDefault();
          calculateRcsVector();
        }
        return;
      }

      // === ОБЫЧНОЕ УПРАВЛЕНИЕ ===
      switch (key) {
        case 'w': case 'ц':
          event.preventDefault();
          act('toggle_rotate_pitch_up', { enable: true });
          break;
        case 's': case 'ы':
          event.preventDefault();
          act('toggle_rotate_pitch_down', { enable: true });
          break;
        case 'a': case 'ф':
          event.preventDefault();
          act('toggle_rotate_left', { enable: true });
          break;
        case 'd': case 'в':
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
      const key = event.key.toLowerCase();

      keysRef.current[key] = false;
      setActiveKeys(prev => ({ ...prev, [key]: false }));

      // === ВЫХОД ИЗ РЕЖИМА RCS ===
      if (key === 'shift') {
        act('set_rcs', { sx: 0, sy: 0, sz: 0, power: 0 });

        if (keysRef.current['w'] || keysRef.current['ц']) act('toggle_rotate_pitch_up', { enable: true });
        if (keysRef.current['s'] || keysRef.current['ы']) act('toggle_rotate_pitch_down', { enable: true });
        if (keysRef.current['a'] || keysRef.current['ф']) act('toggle_rotate_left', { enable: true });
        if (keysRef.current['d'] || keysRef.current['в']) act('toggle_rotate_right', { enable: true });
        return;
      }

      // === ОБНОВЛЕНИЕ ВЕКТОРА RCS ===
      if (keysRef.current['shift']) {
        if (rcsKeys.includes(key)) {
          calculateRcsVector();
        }
        return;
      }

      // === ОБЫЧНОЕ УПРАВЛЕНИЕ (Отпускание) ===
      switch (key) {
        case 'w': case 'ц': act('toggle_rotate_pitch_up', { enable: false }); break;
        case 's': case 'ы': act('toggle_rotate_pitch_down', { enable: false }); break;
        case 'a': case 'ф': act('toggle_rotate_left', { enable: false }); break;
        case 'd': case 'в': act('toggle_rotate_right', { enable: false }); break;
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

  return { cameraYaw, cameraPitch, zoomScale, rotateCamera, handleZoom, activeKeys };
};
