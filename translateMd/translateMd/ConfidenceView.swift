import SwiftUI

struct ConfidenceView: View {
    let confidence: Double
    @State private var showingDetails = false
    
    private var confidenceColor: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var confidenceIcon: String {
        if confidence >= 0.8 {
            return "checkmark.circle.fill"
        } else if confidence >= 0.6 {
            return "exclamationmark.triangle.fill"
        } else {
            return "xmark.circle.fill"
        }
    }
    
    private var confidenceText: String {
        if confidence >= 0.8 {
            return "High Confidence"
        } else if confidence >= 0.6 {
            return "Medium Confidence"
        } else {
            return "Low Confidence"
        }
    }
    
    var body: some View {
        Button(action: { showingDetails = true }) {
            Image(systemName: confidenceIcon)
                .foregroundColor(confidenceColor)
                .font(.title3)
        }
        .sheet(isPresented: $showingDetails) {
            ConfidenceDetailView(confidence: confidence, confidenceText: confidenceText)
        }
    }
}

struct ConfidenceDetailView: View {
    let confidence: Double
    let confidenceText: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: confidence >= 0.8 ? "checkmark.circle.fill" : 
                      confidence >= 0.6 ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(confidence >= 0.8 ? .green : 
                                   confidence >= 0.6 ? .orange : .red)
                
                Text(confidenceText)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Confidence Score: \(Int(confidence * 100))%")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                ProgressView(value: confidence, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: confidence >= 0.8 ? .green : 
                                                             confidence >= 0.6 ? .orange : .red))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("What affects confidence:")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("• Speech recognition clarity")
                    Text("• Translation complexity")
                    Text("• Language pair coverage")
                    Text("• Audio quality")
                }
                .font(.body)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                if confidence < 0.7 {
                    VStack(spacing: 10) {
                        Text("Low confidence detected")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        HStack(spacing: 20) {
                            Button("Repeat") {
                                // Action to repeat the last translation
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Confirm") {
                                // Action to confirm the translation is correct
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Translation Confidence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ConfidenceView(confidence: 0.85)
}