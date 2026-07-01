// useShuttleControls.ts
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

  // Keyboard controls
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (!linkedToShuttle || isDocked) return;
      if (document.activeElement && ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement.tagName)) return;

      const key = event.key.toLowerCase();
      if (['w', 'ц'].includes(key)) { event.preventDefault(); act('toggle_rotate_pitch_up', { enable: true }); }
      else if (['s', 'ы'].includes(key)) { event.preventDefault(); act('toggle_rotate_pitch_down', { enable: true }); }
      else if (['a', 'ф'].includes(key)) { event.preventDefault(); act('toggle_rotate_left', { enable: true }); }
      else if (['d', 'в'].includes(key)) { event.preventDefault(); act('toggle_rotate_right', { enable: true }); }
      else if (key === 'q') { event.preventDefault(); act('set_thrust', { angle: shuttleAngle, power: Math.max(shuttleThrust - 10, 0), pitch: shuttlePitch || 0 }); }
      else if (key === 'e') { event.preventDefault(); act('set_thrust', { angle: shuttleAngle, power: Math.min(shuttleThrust + 10, 100), pitch: shuttlePitch || 0 }); }
      else if (key === 'x') { event.preventDefault(); act('kill_thrust'); }
    };

    const handleKeyUp = (event: KeyboardEvent) => {
      if (!linkedToShuttle || isDocked) return;
      const key = event.key.toLowerCase();
      if (['w', 'ц'].includes(key)) act('toggle_rotate_pitch_up', { enable: false });
      else if (['s', 'ы'].includes(key)) act('toggle_rotate_pitch_down', { enable: false });
      else if (['a', 'ф'].includes(key)) act('toggle_rotate_left', { enable: false });
      else if (['d', 'в'].includes(key)) act('toggle_rotate_right', { enable: false });
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

  return {
    cameraYaw,
    cameraPitch,
    zoomScale,
    rotateCamera,
    handleZoom,
  };
};
