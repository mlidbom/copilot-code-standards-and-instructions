namespace Studio.Speech.Voices;

/// <summary>Identifies a <see cref="Voice"/>: the name its <see cref="ISpeechProvider"/> knows it by.</summary>
public readonly record struct VoiceId(string Value);
