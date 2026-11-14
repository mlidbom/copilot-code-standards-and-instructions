using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace Studio.Speech.Voices;

/// <summary>Which <see cref="Voice"/> speaks each <see cref="TextKind"/>, as the student chose.</summary>
/// <remarks>
/// A choice is made among <see cref="VoiceCatalog.All"/>, and <see cref="Load"/> rejects a settings file that names a voice<br/>
/// the <see cref="VoiceCatalog"/> doesn't have, or that lacks a <see cref="TextKind"/>.
/// </remarks>
public sealed class VoiceSettings
{
   readonly Dictionary<TextKind, VoiceId> _voiceIdByTextKind;

   VoiceSettings(Dictionary<TextKind, VoiceId> voiceIdByTextKind) => _voiceIdByTextKind = voiceIdByTextKind;

   /// <summary>The id of the voice the student chose for <paramref name="textKind"/>.</summary>
   public VoiceId VoiceIdFor(TextKind textKind) => _voiceIdByTextKind[textKind];

   /// <summary>Reads the settings in <paramref name="file"/>, which must name a voice of <paramref name="catalog"/> for every <see cref="TextKind"/>.</summary>
   public static VoiceSettings Load(FileInfo file, VoiceCatalog catalog)
   {
      var voiceIdByTextKind = JsonSerializer.Deserialize<Dictionary<TextKind, string>>(File.ReadAllText(file.FullName))!
                                            .ToDictionary(it => it.Key, it => new VoiceId(it.Value));

      var idsInTheCatalog = catalog.All.Select(it => it.Id).ToHashSet();
      foreach(var textKind in Enum.GetValues<TextKind>())
      {
         if(!voiceIdByTextKind.TryGetValue(textKind, out var voiceId)) throw new InvalidDataException($"{file.FullName} has no voice for {textKind}");
         if(!idsInTheCatalog.Contains(voiceId)) throw new InvalidDataException($"{file.FullName} names the voice {voiceId.Value} for {textKind}, which no speech provider has");
      }

      return new VoiceSettings(voiceIdByTextKind);
   }
}
