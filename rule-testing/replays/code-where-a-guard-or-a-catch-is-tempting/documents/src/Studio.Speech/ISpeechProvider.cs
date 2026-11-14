using Studio.Speech.Voices;

namespace Studio.Speech;

/// <summary>A text-to-speech service, such as a cloud provider's.</summary>
public interface ISpeechProvider
{
   /// <summary>Synthesizes <paramref name="text"/> spoken by <paramref name="voice"/>, by calling the service over the network.</summary>
   Mp3Audio Synthesize(Voice voice, string text);
}
