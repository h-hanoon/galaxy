import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class BodyDetailSheet extends StatelessWidget {
  final String body; // 'sun' or 'moon'

  const BodyDetailSheet({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    final isSun = body == 'sun';
    final accentColor = isSun ? Colors.amber : const Color(0xFFB0BEC5);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: const Color(0xFF080820),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Label row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Icon(
                  isSun ? Icons.wb_sunny : Icons.nightlight_round,
                  color: accentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isSun ? 'The Sun' : 'The Moon',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          // 3D model viewer
          Expanded(
            flex: 5,
            child: ModelViewer(
              src: isSun ? 'lib/assets/sun.glb' : 'lib/assets/the_moon.glb',
              autoRotate: true,
              autoRotateDelay: 0,
              rotationPerSecond: '8deg',
              cameraControls: true,
              disableZoom: false,
              backgroundColor: const Color(0xFF080820),
              interactionPrompt: InteractionPrompt.none,
            ),
          ),
          // Description
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              child: Text(
                isSun ? _sunDescription : _moonDescription,
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
}

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
