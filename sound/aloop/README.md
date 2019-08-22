# ALSA PCM dummy (snd-dummy) and loopback test (snd-aloop)

The snd-dummy driver is used to silently consume playback samples.

The snd-aloop driver is used to check the PCM playback and the PCM recording (capture).

Test Maintainer: [Jaroslav Kysela](mailto:jkysela@redhat.com)

## How to run it
Please refer to the top-level README.md for common dependencies. Test-specific dependencies will automatically be installed when executing 'make run'. For a complete detail, see PURPOSE file.

### Execute the test
```bash
$ make run
```
