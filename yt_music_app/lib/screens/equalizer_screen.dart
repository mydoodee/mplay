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
        appBar: AppBar(backgroundColor: Colors.black, title: const Text('Equalizer')),
        body: const Center(child: Text('Equalizer not available', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Equalizer',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Switch to enable/disable equalizer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'เปิดใช้งาน Equalizer',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Switch(
                  value: eqProvider.isEqualizerEnabled,
                  onChanged: (val) {
                    eqProvider.setEnabled(val);
                  },
                  activeColor: const Color(0xFFF15A24),
                  inactiveThumbColor: const Color(0xFF777777),
                  inactiveTrackColor: const Color(0xFF333333),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF222222), height: 1),
          const SizedBox(height: 24),
          
          Expanded(
            child: Opacity(
              opacity: eqProvider.isEqualizerEnabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !eqProvider.isEqualizerEnabled,
                child: Column(
                  children: [
                    // Presets
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: eqProvider.presets.map((preset) {
                          final isSelected = preset == eqProvider.selectedPreset;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ChoiceChip(
                              label: Text(preset),
                              selected: isSelected,
                              showCheckmark: false,
                              onSelected: (selected) {
                                if (selected) {
                                  eqProvider.setPreset(preset);
                                }
                              },
                              backgroundColor: const Color(0xFF1A1A1A),
                              selectedColor: const Color(0xFFF15A24).withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: isSelected ? const Color(0xFFF15A24) : const Color(0xFFAAAAAA),
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFFF15A24).withValues(alpha: 0.5) : const Color(0xFF333333),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Sliders
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(eqProvider.bands.length, (index) {
                          return _buildSlider(context, eqProvider, index);
                        }),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Bass Booster
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Bass Booster', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                              Text('${eqProvider.bassBoosterLevel.round()}%', style: const TextStyle(color: Color(0xFFF15A24), fontSize: 16, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFF15A24),
                              inactiveTrackColor: const Color(0xFF2A2A2A),
                              thumbColor: Colors.white,
                              overlayColor: const Color(0xFFF15A24).withValues(alpha: 0.2),
                              trackHeight: 6,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                            ),
                            child: Slider(
                              value: eqProvider.bassBoosterLevel,
                              min: 0,
                              max: 100,
                              onChanged: (val) {
                                eqProvider.setBassBoosterLevel(val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(BuildContext context, EqualizerProvider eqProvider, int index) {
    final List<String> bandLabels = [
      'Sub Bass', 
      'Bass', 
      'Low-Mid', 
      'Midrange', 
      'Upper-Mid', 
      'Presence', 
      'Brilliance'
    ];

    return Column(
      children: [
        const Text(
          '+15 dB',
          style: TextStyle(color: Color(0xFF666666), fontSize: 10),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFF15A24),
                inactiveTrackColor: const Color(0xFF2A2A2A),
                thumbColor: Colors.white,
                overlayColor: const Color(0xFFF15A24).withValues(alpha: 0.2),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: eqProvider.bandValues[index].clamp(-15.0, 15.0),
                min: -15,
                max: 15,
                onChanged: (val) {
                  eqProvider.setBandValue(index, val);
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '-15 dB',
          style: TextStyle(color: Color(0xFF666666), fontSize: 10),
        ),
        const SizedBox(height: 16),
        Text(
          eqProvider.bands[index],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (bandLabels[index].isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            bandLabels[index],
            style: const TextStyle(
              color: Color(0xFFF15A24),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else ...[
          const SizedBox(height: 14), // Keep alignment
        ],
      ],
    );
  }
}
