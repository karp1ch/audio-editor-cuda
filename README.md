# Program do Przetwarzania Dźwięku CUDA


## Opis
Ten projekt jest aplikacją do przetwarzania dźwięku wykorzystującą CUDA. 
Umożliwia ona wykonanie różnych operacji na plikach dźwiękowych WAV 16-bitowych, takich jak usuwanie szumów, zmiana głośności, dodawanie pogłosu, zanikanie dźwięku (fade in/out) oraz zmiana prędkości odtwarzania.


## Wymagania
- NVIDIA GPU z obsługą CUDA
- Zainstalowane narzędzia CUDA Toolkit

## Funkcje
1. `removeNoise`: Usuwa szumy z dźwięku.
2. `calculateNoiseThresholdKernel`: Oblicza próg szumu.
3. `increaseVolume`: Zwiększa głośność dźwięku.
4. `normalizeAudio`: Normalizuje dźwięk do określonego poziomu.
5. `addReverb`: Dodaje efekt pogłosu.
6. `fadeIn`: Stopniowe zwiększanie głośności (fade in).
7. `fadeOut`: Stopniowe zmniejszanie głośności (fade out).
8. `changeSpeed`: Zmienia prędkość odtwarzania dźwięku.

## Instrukcja Użycia
1. Umieść plik dzwiękowy formatu WAV (16 bit) w folderze z programem pod nazwą.
2. Skompiluj program za pomocą kompilatora NVCC.
3. Uruchom program i postępuj zgodnie z instrukcjami w celu wprowadzenia parametrów obróbki dźwięku.
4. Program przetworzy plik `input.wav` i zapisze wynik w pliku `output.wav`.

## Interfejs
![image](https://github.com/karp1ch/audio-editor-cuda/assets/106777205/9de8c4c4-e89e-4bc9-8a1a-3bc34588c65e)

*Interfejs naszego programu: przykładowe wprowadzenie parametrów*

![image](https://github.com/karp1ch/audio-editor-cuda/assets/106777205/94528d4b-21c3-4eb5-bff8-117dfe711e5d)

*Interfejs Audacity: widać że plik podległ modyfikacji*


## Uwagi
- Upewnij się, że plik wejściowy jest w formacie WAV z odpowiednimi parametrami.
- Wyniki mogą się różnić w zależności od specyfikacji sprzętowej i parametrów wejściowych.
