import { useState, useEffect, useCallback } from 'react';

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

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (!linkedToShuttle || isDocked) return;
      if (document.activeElement && ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement.tagName)) return;
      const key = event.key.toLowerCase();
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

      switch (key) {
        case 'w': case 'ц':
          act('toggle_rotate_pitch_up', { enable: false });
          break;
        case 's': case 'ы':
          act('toggle_rotate_pitch_down', { enable: false });
          break;
        case 'a': case 'ф':
          act('toggle_rotate_left', { enable: false });
          break;
        case 'd': case 'в':
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

  return { cameraYaw, cameraPitch, zoomScale, rotateCamera, handleZoom };
};
