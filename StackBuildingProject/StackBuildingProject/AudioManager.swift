import Foundation
import RealityKit

@MainActor
class AudioManager {
    // Singleton: ci permette di accedere all'audio da ovunque scrivendo AudioManager.shared
    static let shared = AudioManager()
    
    private var sounds: [String: AudioFileResource] = [:]
    
    // Carica tutti i suoni in memoria all'avvio
    func loadSounds() async {
        do {
            // CORREZIONE ERRORI XCODE:
            // Invece di .load(named:), usiamo l'inizializzatore async AudioFileResource(named:)
            // Questo evita di bloccare l'interfaccia mentre carica i file.
            
            sounds["hit"] = try await AudioFileResource(named: "hit.mp3")
            sounds["gameover"] = try await AudioFileResource(named: "gameover.mp3")
            
            print("🔊 Step 12: Suoni caricati con successo!")
        } catch {
            print("⚠️ Errore caricamento suoni: \(error.localizedDescription)")
            print("SUGGERIMENTO: Hai trascinato hit.mp3 e gameover.mp3 nel progetto e spuntato 'Add to targets'?")
        }
    }
    
    // Riproduce un suono da una specifica entità (Audio Spaziale)
    func play(_ name: String, from sourceEntity: Entity) {
        guard let resource = sounds[name] else {
            // Se il suono non è stato caricato (o il nome è sbagliato), esce senza crashare
            return
        }
        
        // Crea un controller audio e riproduce il suono dalla posizione dell'oggetto
        sourceEntity.playAudio(resource)
    }
}
