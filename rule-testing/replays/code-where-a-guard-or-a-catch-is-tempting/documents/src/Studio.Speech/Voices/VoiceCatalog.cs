using System.Collections.Generic;
using System.Linq;

namespace Studio.Speech.Voices;

/// <summary>Every <see cref="Voice"/> the application can speak with. Built once at startup, from each <see cref="ISpeechProvider"/>'s voices.</summary>
public sealed class VoiceCatalog
{
   readonly Dictionary<VoiceId, Voice> _voicesById;

   public VoiceCatalog(IEnumerable<Voice> voices) => _voicesById = voices.ToDictionary(it => it.Id);

   /// <summary>All the voices, for the student to choose among.</summary>
   public IReadOnlyCollection<Voice> All => _voicesById.Values;
}
