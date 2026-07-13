export interface MapObject {
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
  docking_range?: number;
  position_history?: Array<number>;
  thrust_x?: number;
  thrust_y?: number;
  thrust_z?: number;
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
  orbit_center_id?: string;
  orbit_radius?: number;
  orbit_inclination?: number;
  orbit_ascension?: number;
  landable?: boolean;
}

export interface NearbyObject {
  id: string;
  name: string;
  distance: number;
  type: string;
  occupied: boolean;
}

export interface JumpDestination {
  id: string;
  name: string;
  description: string;
}

export interface SupercruiseMapData {
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
  autopilotMode?: number;
  targetObjectId?: string | null;
}
