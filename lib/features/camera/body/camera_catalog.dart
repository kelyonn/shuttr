/// The words on each camera's card: roughly when it's from, the story, and
/// what it's best for. User-facing copy lives here in one place (ready for
/// localisation). No real brand or stock names (CLAUDE.md rule 4).
class CameraInfo {
  const new({
    required this.era,
    required this.story,
    required this.bestFor,
    required this.traits,
  });

  final String era;
  final String story;
  final List<String> bestFor;
  final List<String> traits;
}

const _fallback = CameraInfo(era: '', story: '', bestFor: [], traits: []);

CameraInfo cameraInfo(String id) => _catalog[id] ?? _fallback;

const _catalog = <String, CameraInfo>{
  'digi03': CameraInfo(
    era: '2003',
    story:
        'The silver 4-megapixel pocket digicam everyone had at parties. '
        'Harsh flash, crunchy JPEG, orange date in the corner.',
    bestFor: ['Parties', 'Friends', 'Night out'],
    traits: ['CCD smear', 'Hard flash', 'Red-eye', 'Date stamp'],
  ),
  'disposable': CameraInfo(
    era: '1990s',
    story:
        'A single-use film camera from the corner shop. Wind the wheel, '
        'hope for the best, pick up prints next week.',
    bestFor: ['Trips', 'Weddings', 'Summer'],
    traits: ['Film grain', 'Light leaks', 'Warm flash', 'Dust'],
  ),
  'instant': CameraInfo(
    era: '1980s',
    story:
        'The print slides out and develops in your hand. Soft, milky, '
        'a little faded from day one.',
    bestFor: ['Portraits', 'Friends', 'Keepsakes'],
    traits: ['White frame', 'Develops for a minute', 'Faded blacks'],
  ),
  'point_and_shoot_35': CameraInfo(
    era: '1995',
    story:
        'A 35mm compact with a motor winder, lab-scanned colour negative. '
        'Warm skin and red halos round the lights.',
    bestFor: ['Portraits', 'Everyday', 'Golden hour'],
    traits: ['Halation', 'Warm skin', 'Fine grain'],
  ),
  'cine_800': CameraInfo(
    era: '2010s',
    story:
        'Movie film made for tungsten light, loaded into a stills camera. '
        'City lights glow red, daylight turns cool.',
    bestFor: ['City at night', 'Neon', 'Moody'],
    traits: ['Red halation', 'Teal shadows', 'Heavy grain'],
  ),
  'mono_400': CameraInfo(
    era: '1970s',
    story:
        'Black-and-white film pushed through a compact. Punchy contrast, '
        'real silver grain.',
    bestFor: ['Street', 'Portraits', 'Drama'],
    traits: ['True B&W response', 'Grain', 'Hard flash'],
  ),
  'video_vhs': CameraInfo(
    era: '1989',
    story:
        'The shoulder camcorder on the family holiday, played back off a '
        'worn tape: soft, smeared colour, tracking lines, hiss.',
    bestFor: ['Family', 'Birthdays', 'Nostalgia'],
    traits: ['Colour bleed', 'Tracking noise', 'Tape hiss', 'Date OSD'],
  ),
  'video_hi8': CameraInfo(
    era: '1995',
    story:
        'The palm-sized camcorder that went on every school trip. Sharper '
        'than VHS, red REC in the corner.',
    bestFor: ['Trips', 'Skate clips', 'Friends'],
    traits: ['REC + counter', 'Edge halos', 'Interlaced'],
  ),
  'video_minidv': CameraInfo(
    era: '2003',
    story:
        'Digital tape: crisp, cool, over-sharpened. Every early-2000s music '
        'video and skate part.',
    bestFor: ['Music videos', 'Skate', 'Y2K'],
    traits: ['Crisp', 'Timecode', 'Cool colour'],
  ),
  'video_digi03': CameraInfo(
    era: '2003',
    story:
        'The movie mode on that silver pocket digicam: tiny, crunchy clips '
        'with the same punchy colour as the photos, and a tinny mic.',
    bestFor: ['Parties', 'Friends', 'Night out'],
    traits: ['Crunchy', 'Blocky compression', 'Noisy', 'Tinny sound'],
  ),
  'video_super8': CameraInfo(
    era: '1970s',
    story:
        'Home movies on 8mm film at 18 frames a second: flicker, gate '
        'weave, dust, warm faded colour.',
    bestFor: ['Weddings', 'Summer', 'Dreamy'],
    traits: ['18 fps', 'Flicker', 'Dust + scratches', 'Projector'],
  ),
  'video_flip': CameraInfo(
    era: '2008',
    story:
        'The pocket flip camera with the USB arm: 720p, over-squeezed, '
        'wobbly, tinny sound.',
    bestFor: ['Parties', 'Vlogs', 'Concerts'],
    traits: ['Compression', 'Jello wobble', 'Tinny mic'],
  ),
  'video_webcam': CameraInfo(
    era: '2006',
    story:
        'The laptop webcam: 640x480 at 15 frames, smeary, green office '
        'light, muddy voice.',
    bestFor: ['Bedroom', 'Messages', 'Memes'],
    traits: ['15 fps', 'Blocky', 'Muddy sound'],
  ),
};
