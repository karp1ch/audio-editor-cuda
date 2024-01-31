# Program do Przetwarzania Dźwięku CUDA


## Opis
Ten projekt jest aplikacją do przetwarzania dźwięku wykorzystującą CUDA. 
Umożliwia ona wykonanie różnych operacji na plikach dźwiękowych WAV 16-bitowych, takich jak usuwanie szumów, zmiana głośności, dodawanie pogłosu, zanikanie dźwięku (fade in/out) oraz zwiększenie prędkości odtwarzania.


## Wymagania
- NVIDIA GPU z obsługą CUDA
- Zainstalowane narzędzia CUDA Toolkit

## Funkcje
1.`calculateNoiseThresholdKernel`: Oblicza próg szumu (średnia głośność na zadanym przedziale).
2. `removeNoise`: Usuwa szumy z dźwięku (na zadanym przedziale zeruje, lub jeśli dzwięk ciszej od thresholda, to zmniejsza).
3. `increaseVolume`: Zwiększa głośność dźwięku.
4. `normalizeAudio`: Normalizuje dźwięk do określonego poziomu.
5. `addReverb`: Dodaje efekt pogłosu.
6. `fadeIn`: Stopniowe zwiększanie głośności (fade in).
7. `fadeOut`: Stopniowe zmniejszanie głośności (fade out).
8. `changeSpeed`: Zwiększa prędkość odtwarzania dźwięku.

## Instrukcja Użycia
1. Umieść plik dzwiękowy formatu WAV (16 bit) w folderze z programem pod nazwą `input.wav`.
2. Skompiluj program.
3. Uruchom program i postępuj zgodnie z instrukcjami w celu wprowadzenia parametrów obróbki dźwięku.
4. Program przetworzy plik `input.wav` i zapisze wynik w pliku `output.wav`.
5. Za pomocą np. Audacity można wizualnie zobaczyć jakim zmianam podległ plik.

## Interfejs
![obraz](https://github.com/karp1ch/audio-editor-cuda/assets/157658045/3f72f552-df27-407d-bfcd-4cebe5a1b98a)

*Interfejs naszego programu: przykładowe wprowadzenie parametrów*

![image](https://github.com/karp1ch/audio-editor-cuda/assets/106777205/94528d4b-21c3-4eb5-bff8-117dfe711e5d)

*Interfejs Audacity: widać że plik podległ modyfikacji*


## Uwagi
- Upewnij się, że plik wejściowy jest w formacie WAV z odpowiednimi parametrami.
- Wyniki mogą się różnić w zależności od specyfikacji sprzętowej i parametrów wejściowych.
- Testowanie było przeprowadzone na plikach nagranych osobiście w Audacity, jak również innych plikach.
- Nie nadaje się do obróbki muzyki.
