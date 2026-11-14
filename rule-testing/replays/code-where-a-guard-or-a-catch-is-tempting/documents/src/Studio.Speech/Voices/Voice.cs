namespace Studio.Speech.Voices;

/// <summary>One voice that an <see cref="ISpeechProvider"/> can synthesize speech with, such as a named neural voice of a cloud service.</summary>
public sealed record Voice(VoiceId Id, string DisplayName, ISpeechProvider Provider);
