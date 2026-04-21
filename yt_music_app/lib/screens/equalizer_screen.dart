import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/equalizer_provider.dart';

class EqualizerScreen extends StatelessWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // If EqualizerProvider is null (e.g. audioHandler failed), show error
    final eqProvider = Provider.of<EqualizerProvider?>(context);

    if (eqProvider == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Equalizer'),
        ),
        body: const Center(
          child: Text(
            'Equalizer not available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF080808),
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [Color(0xFF1A1A1A), Color(0xFF080808)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'ปรับแต่งเสียง',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    Switch(
                      value: eqProvider.isEqualizerEnabled,
                      activeThumbColor: const Color(0xFFF15A24),
                      onChanged: eqProvider.setEnabled,
                    ),
                  ],
                ),
              ),

              // ── Content ──
              Expanded(
                child: IgnorePointer(
                  ignoring: !eqProvider.isEqualizerEnabled,
                  child: AnimatedOpacity(
                    opacity: eqProvider.isEqualizerEnabled ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // 🎨 Presets - horizontal scroll
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: eqProvider.presets.map((preset) {
                              final isSelected =
                                  preset == eqProvider.selectedPreset;
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: GestureDetector(
                                  onTap: () => eqProvider.setPreset(preset),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(25),
                                      gradient: isSelected
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFFF15A24),
                                                Color(0xFFED1C24),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      color: isSelected
                                          ? null
                                          : const Color(0xFF151515),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(
                                                0xFFF15A24,
                                              ).withValues(alpha: 0.5)
                                            : const Color(0xFF2A2A2A),
                                        width: 1.5,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFFF15A24,
                                                ).withValues(alpha: 0.3),
                                                blurRadius: 12,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Text(
                                      preset,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFFAAAAAA),
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 🎚 EQ Sliders — takes remaining space
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(
                                eqProvider.bands.length,
                                (index) =>
                                    _buildSlider(context, eqProvider, index),
                              ),
                            ),
                          ),
                        ),

                        // ── Bass Booster ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'เร่งเบส',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${eqProvider.bassBoosterLevel.round()}%',
                                    style: const TextStyle(
                                      color: Color(0xFFF15A24),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFFF15A24),
                                  inactiveTrackColor: const Color(0xFF1A1A1A),
                                  thumbColor: Colors.white,
                                  overlayColor: const Color(
                                    0xFFF15A24,
                                  ).withValues(alpha: 0.2),
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 9,
                                    elevation: 4,
                                  ),
                                ),
                                child: Slider(
                                  value: eqProvider.bassBoosterLevel,
                                  min: 0,
                                  max: 100,
                                  onChanged: eqProvider.setBassBoosterLevel,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider(
    BuildContext context,
    EqualizerProvider eqProvider,
    int index,
  ) {
    final List<String> bandLabels = [
      'ซับเบส',
      'เบส',
      'กลาง-ต่ำ',
      'กลาง',
      'กลาง-สูง',
      'แหลม',
      'ความใส',
    ];

    return Expanded(
      child: Column(
        children: [
          // ── Hz label ──
          Text(
            eqProvider.bands[index],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),

          // ── Vertical Slider ──
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFFF15A24),
                  inactiveTrackColor: const Color(0xFF151515),
                  thumbColor: Colors.white,
                  overlayColor: const Color(0xFFF15A24).withValues(alpha: 0.2),
                  trackHeight: 2.5,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                    elevation: 3,
                  ),
                ),
                child: Slider(
                  value: eqProvider.bandValues[index].clamp(-15.0, 15.0),
                  min: -15,
                  max: 15,
                  onChanged: (val) => eqProvider.setBandValue(index, val),
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // ── Band name label ──
          Text(
            bandLabels[index],
            style: const TextStyle(
              color: Color(0xFFF15A24),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
