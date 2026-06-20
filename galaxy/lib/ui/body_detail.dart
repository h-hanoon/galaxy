import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'star_field.dart';

const _kConstellations = {'Orion', 'Ursa Major', 'Cassiopeia'};

class BodyDetailSheet extends StatelessWidget {
  final String body;

  const BodyDetailSheet({super.key, required this.body});

  bool get _isSun => body == 'sun';
  bool get _isMoon => body == 'moon';
  bool get _isConstellation => _kConstellations.contains(body);

  @override
  Widget build(BuildContext context) {
    if (_isConstellation) return _buildConstellationSheet(context);

    final color = _isSun
        ? Colors.amber
        : _isMoon
            ? const Color(0xFFB0BEC5)
            : planetColor(body);

    final name = _isSun
        ? 'The Sun'
        : _isMoon
            ? 'The Moon'
            : '${body[0].toUpperCase()}${body.substring(1)}';

    final icon = _isSun
        ? Icons.wb_sunny
        : _isMoon
            ? Icons.nightlight_round
            : Icons.circle;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: const Color(0xFF080820),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _dragHandle(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: ModelViewer(
              src: _glbPath(body),
              autoRotate: true,
              autoRotateDelay: 0,
              rotationPerSecond: '8deg',
              cameraControls: true,
              disableZoom: false,
              backgroundColor: const Color(0xFF080820),
              interactionPrompt: InteractionPrompt.none,
            ),
          ),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              child: Text(
                _bodyDescription(body),
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14.5,
                  height: 1.7,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConstellationSheet(BuildContext context) {
    const color = Color(0xFF8EC8E8);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: const Color(0xFF080820),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dragHandle(),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  body,
                  style: const TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          // Big decorative title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  body.toUpperCase(),
                  style: TextStyle(
                    color: color.withValues(alpha: 0.12),
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 48,
                  height: 1.5,
                  color: color.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
          // Description — large text, full remaining space
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
              child: Text(
                _bodyDescription(body),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 17,
                  height: 1.85,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dragHandle() => Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

String _glbPath(String body) => switch (body) {
  'sun'     => 'lib/assets/sun.glb',
  'moon'    => 'lib/assets/the_moon.glb',
  'mercury' => 'lib/assets/mercury_natural_color.glb',
  'venus'   => 'lib/assets/venus.glb',
  'mars'    => 'lib/assets/mars.glb',
  'jupiter' => 'lib/assets/jupiter.glb',
  'saturn'  => 'lib/assets/saturno_v1.1.glb',
  'uranus'  => 'lib/assets/uranus.glb',
  'neptune' => 'lib/assets/neptune.glb',
  _         => 'lib/assets/sun.glb',
};

String _bodyDescription(String body) => switch (body) {
  'sun'         => _sunDescription,
  'moon'        => _moonDescription,
  'mercury'     => _mercuryDescription,
  'venus'       => _venusDescription,
  'mars'        => _marsDescription,
  'jupiter'     => _jupiterDescription,
  'saturn'      => _saturnDescription,
  'uranus'      => _uranusDescription,
  'neptune'     => _neptuneDescription,
  'Orion'       => _orionDescription,
  'Ursa Major'  => _ursaMajorDescription,
  'Cassiopeia'  => _cassiopeiaDescription,
  _             => '',
};

const String _sunDescription =
    'The Sun is the star at the centre of our Solar System — a nearly perfect '
    'sphere of hot plasma threaded with magnetic fields. With a diameter of about '
    '1.39 million kilometres, it accounts for over 99.86 % of the total mass of '
    'the Solar System.\n\n'
    'At its core, temperatures reach 15 million degrees Celsius, where hydrogen '
    'is continuously fused into helium through nuclear fusion. Each second the Sun '
    'converts roughly 4 million tonnes of matter into pure energy, radiating light '
    'and heat that drive nearly every process of life on Earth.\n\n'
    'The visible surface — the photosphere — glows at around 5,500 °C and is '
    'peppered with sunspots: regions of intense magnetic activity that appear '
    'darker because they are slightly cooler. Above the photosphere lies the '
    'chromosphere and the corona, an ethereal halo of superheated plasma extending '
    'millions of kilometres into space.\n\n'
    'Our Sun is about 4.6 billion years old and sits squarely in the middle of '
    'its life. It will continue to shine for another 5 billion years before '
    'swelling into a red giant large enough to engulf the inner planets.';

const String _moonDescription =
    'The Moon is Earth\'s only natural satellite and the fifth-largest moon in '
    'the Solar System. Orbiting at an average distance of 384,400 km, it is the '
    'closest celestial body to Earth — and the only world beyond our planet that '
    'humans have walked upon.\n\n'
    'Its surface is a frozen record of the Solar System\'s violent youth: ancient '
    'lava plains called maria, towering mountain ranges, and countless craters '
    'carved by billions of years of meteorite bombardment with no atmosphere to '
    'offer protection.\n\n'
    'The Moon\'s gravitational pull stretches Earth\'s oceans into the bulges we '
    'experience as tides. Its slow, tidally locked rotation means we always see '
    'the same nearside face from the ground — the farside remained completely '
    'unknown until the Space Age.\n\n'
    'The Moon most likely formed about 4.5 billion years ago from debris flung '
    'into orbit when a Mars-sized body collided with the early Earth. Today it '
    'drifts very slightly farther away each year — about 3.8 cm annually — a '
    'quiet reminder that our cosmic neighbourhood is still evolving.';

const String _mercuryDescription =
    'Mercury is the smallest planet in the Solar System and the closest to the '
    'Sun, racing through an orbit just 88 Earth-days long. Its surface swings '
    'between 430 °C in full sunlight and −180 °C in the long polar nights — the '
    'most extreme temperature range of any planet.\n\n'
    'Without a substantial atmosphere, Mercury has no weather to erode its '
    'billion-year-old craters and impact basins. Its enormous iron core makes up '
    'about 85 % of the planet\'s radius, generating a weak but persistent '
    'magnetic field that deflects the solar wind.\n\n'
    'Despite being the smallest planet, Mercury is surprisingly dense — second '
    'only to Earth — evidence that it lost much of its rocky mantle in a giant '
    'impact early in Solar System history. MESSENGER, the first spacecraft to '
    'orbit Mercury, revealed flood-basalt plains, towering scarps, and mysterious '
    'hollows carved by escaping volatiles.';

const String _venusDescription =
    'Venus is the second planet from the Sun and Earth\'s nearest planetary '
    'neighbour, yet almost nothing else about it is familiar. Its thick '
    'carbon-dioxide atmosphere generates a runaway greenhouse effect, pushing '
    'surface temperatures to 465 °C — hot enough to melt lead — making Venus the '
    'hottest planet in the Solar System despite not being the closest to the '
    'Sun.\n\n'
    'The surface is hidden beneath a permanent blanket of sulphuric-acid clouds '
    'and reshaped by massive volcanic eruptions. Atmospheric pressure at the '
    'surface is 92 times that at sea level on Earth — equivalent to being 900 m '
    'underwater.\n\n'
    'Venus rotates backwards relative to most planets, and so slowly that a '
    'Venusian day is longer than its year. From the surface, the Sun would rise '
    'in the west and set in the east — if the clouds ever parted long enough to '
    'see it.';

const String _marsDescription =
    'Mars is the fourth planet from the Sun and humanity\'s most explored '
    'planetary neighbour. Its rust-red colour comes from iron oxide coating its '
    'ancient surface, and its thin carbon-dioxide atmosphere creates a pale '
    'butterscotch sky. Average temperatures hover around −60 °C, though summer '
    'afternoons near the equator can reach a pleasant 20 °C.\n\n'
    'Mars hosts the Solar System\'s tallest volcano — Olympus Mons, 22 km high — '
    'and its longest canyon system, Valles Marineris, which stretches 4,000 km '
    'across a quarter of the planet\'s circumference. Polar ice caps of water and '
    'carbon-dioxide ice expand and contract with the seasons.\n\n'
    'Evidence from orbiters and rovers shows Mars once had liquid water on its '
    'surface: ancient river valleys, lake beds, and minerals that only form in the '
    'presence of water. NASA\'s Perseverance rover is searching for signs of '
    'ancient microbial life in the Jezero Crater.';

const String _jupiterDescription =
    'Jupiter is the largest planet in the Solar System — more than 1,300 Earths '
    'would fit inside it — and the first of the gas giants. Its iconic cloud '
    'bands are vast jet streams moving in opposite directions, and the Great Red '
    'Spot is a storm that has raged for at least 350 years, wider than Earth '
    'itself.\n\n'
    'Jupiter\'s rapid ten-hour rotation drives fierce winds exceeding 500 km/h '
    'and generates a magnetic field 14 times stronger than Earth\'s, creating '
    'intense radiation belts lethal to unshielded spacecraft.\n\n'
    'With 95 known moons, Jupiter is a miniature solar system. The four Galilean '
    'moons — Io, Europa, Ganymede, and Callisto — rival the inner rocky planets '
    'in size. Europa\'s subsurface ocean, kept liquid by tidal heating, is '
    'considered one of the most promising places to look for life beyond Earth.';

const String _saturnDescription =
    'Saturn is the sixth planet from the Sun and the most visually spectacular: '
    'its ring system — mostly water-ice particles ranging from grains of sugar to '
    'house-sized boulders — extends up to 282,000 km from the planet\'s centre '
    'yet is typically only tens of metres thick.\n\n'
    'A gas giant slightly smaller than Jupiter, Saturn is so low in density that '
    'it would float on water. Its rapid rotation and low density give it a '
    'noticeably oblate shape, bulging at the equator and flattened at the '
    'poles.\n\n'
    'Saturn has 146 known moons — more than any other planet. Titan, the largest, '
    'is the only moon with a thick atmosphere; it hosts lakes and rivers of liquid '
    'methane. Enceladus jets water vapour into space from a buried ocean, offering '
    'another candidate for extraterrestrial life.';

const String _uranusDescription =
    'Uranus is the seventh planet from the Sun and the first discovered with a '
    'telescope, by William Herschel in 1781. It is an ice giant — its interior is '
    'mostly a hot, slushy mixture of water, methane, and ammonia — and its '
    'pale blue-green colour comes from methane absorbing red light in its '
    'atmosphere.\n\n'
    'Uranus has the most extreme axial tilt of any planet — 98 degrees — meaning '
    'it orbits the Sun effectively rolling on its side. Each pole endures '
    '42 years of continuous sunlight followed by 42 years of darkness. Despite '
    'receiving as much solar energy as Neptune, Uranus radiates almost no '
    'internal heat — a mystery that remains unsolved.\n\n'
    'The planet has 13 rings and 28 known moons, most named after characters '
    'from Shakespeare and Alexander Pope. Voyager 2 remains the only spacecraft '
    'to have visited Uranus, during a single flyby in 1986.';

const String _neptuneDescription =
    'Neptune is the eighth and farthest planet from the Sun — a dark, cold world '
    'at an average temperature of −200 °C, orbiting more than 30 times farther '
    'from the Sun than Earth. Like Uranus it is an ice giant, and its deep blue '
    'colour comes from methane absorbing red wavelengths of light.\n\n'
    'Neptune has the strongest sustained winds in the Solar System, exceeding '
    '2,100 km/h. Its Great Dark Spot — first seen by Voyager 2 in 1989 — was an '
    'anticyclone the size of Earth, though later observations showed it had '
    'vanished and new storms had formed in its place.\n\n'
    'Despite receiving only 1/900th as much sunlight as Earth, Neptune radiates '
    '2.6 times more heat than it receives, driven by slow gravitational '
    'contraction. Its largest moon, Triton, orbits backwards and is almost '
    'certainly a captured Kuiper Belt object, destined to be torn apart by tidal '
    'forces in about 3.6 billion years.';

const String _orionDescription =
    'Orion the Hunter is one of the most recognisable constellations in the night '
    'sky, visible from virtually every corner of the Earth. Named after the giant '
    'huntsman of Greek mythology, it dominates the winter sky in the northern '
    'hemisphere and the summer sky in the southern.\n\n'
    'The constellation\'s most distinctive feature is the Belt of Orion — three '
    'bright stars in a nearly perfect straight line: Mintaka, Alnilam, and '
    'Alnitak. Below the belt hangs the Orion Nebula (M42), one of the '
    'most-studied objects in the sky and an active stellar nursery where new stars '
    'are being born right now.\n\n'
    'Two supergiants anchor the figure: blood-red Betelgeuse marks the hunter\'s '
    'shoulder — a dying star so enormous it could swallow the entire inner Solar '
    'System — while brilliant blue-white Rigel blazes at his opposite foot, one '
    'of the most luminous stars known.\n\n'
    'The belt stars rise nearly due east and set nearly due west from any point '
    'on Earth, making Orion a reliable compass used by sailors, travellers, and '
    'astronomers across cultures for thousands of years.';

const String _ursaMajorDescription =
    'Ursa Major — the Great Bear — is one of the oldest named constellations, '
    'recognised by peoples across Europe, Asia, and the Americas long before '
    'written history. Its most familiar asterism, the Big Dipper (or Plough in '
    'British tradition), forms a ladle shape that serves as a celestial signpost '
    'across the northern sky all year long.\n\n'
    'The two stars at the far end of the Dipper\'s bowl — Dubhe and Merak — are '
    'known as the Pointer Stars: extend a line through them five times its length '
    'and it points directly to Polaris, the North Star, making the Big Dipper '
    'the most widely used natural compass in history.\n\n'
    'Most of the Dipper\'s stars are gravitationally related, forming the Ursa '
    'Major Moving Group — a loose cluster born from the same gas cloud roughly '
    '300 million years ago and still moving together through space.\n\n'
    'Mizar, the second star from the end of the handle, has a faint companion '
    'Alcor just visible to the naked eye — a test of sharp vision used since '
    'antiquity and today known to be a genuine wide binary system.';

const String _cassiopeiaDescription =
    'Cassiopeia the Queen sits directly across Polaris from the Big Dipper, '
    'making it circumpolar from most northern latitudes — it never dips below '
    'the horizon. Its five brightest stars form an unmistakeable W or M shape '
    'depending on its orientation, one of the most instantly recognisable '
    'patterns in the sky.\n\n'
    'In Greek mythology, Cassiopeia was a vain Ethiopian queen who boasted that '
    'her daughter Andromeda surpassed the sea nymphs in beauty, drawing the wrath '
    'of Poseidon. As punishment she was placed in the heavens, forever circling '
    'the celestial pole — sometimes hanging upside down in an undignified pose.\n\n'
    'The constellation straddles the band of the Milky Way and contains several '
    'striking deep-sky objects, including the open clusters M52 and the Owl '
    'Cluster (NGC 457), whose two bright stars resemble a pair of glowing eyes.\n\n'
    'In November 1572, Tycho Brahe observed a brilliant new star blaze into view '
    'within Cassiopeia — now called Tycho\'s Supernova. Visible in daylight for '
    'weeks, it shattered the ancient belief that the heavens were fixed and '
    'unchanging, helping lay the groundwork for the Scientific Revolution.';
