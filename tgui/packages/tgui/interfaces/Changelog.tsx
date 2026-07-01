import { Window } from '../layouts';

export function Changelog() {
  return (
    <Window title="Horizon Changelog" width={700} height={720}>
      <Window.Content>
        <iframe
          style={{ width: '100%', height: '100%', border: 'none' }}
          src="https://horizon-dev-team.github.io/Horizon-Changelog/"
        />
      </Window.Content>
    </Window>
  );
}
