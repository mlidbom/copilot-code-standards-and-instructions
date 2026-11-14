namespace Studio.Speech;

/// <summary>Plays audio on the machine's default output device.</summary>
public interface IAudioPlayer
{
   /// <summary>Plays <paramref name="audio"/> from start to end, and returns when it has finished.</summary>
   void Play(Mp3Audio audio);
}
