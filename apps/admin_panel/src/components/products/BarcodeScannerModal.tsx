import React, { useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';
import { FaBarcode, FaCamera, FaTimes, FaKeyboard } from 'react-icons/fa';
import { toast } from 'react-hot-toast';

interface BarcodeScannerModalProps {
  isOpen: boolean;
  onClose: () => void;
  onScan: (barcode: string) => void;
}

export const BarcodeScannerModal: React.FC<BarcodeScannerModalProps> = ({
  isOpen,
  onClose,
  onScan
}) => {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const [manualCode, setManualCode] = useState('');
  const [hasCamera, setHasCamera] = useState(true);
  const [cameraError, setCameraError] = useState<string | null>(null);

  useEffect(() => {
    if (!isOpen) return;

    let active = true;
    const isBarcodeDetectorSupported = 'BarcodeDetector' in window;

    const startCamera = async () => {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: 'environment' }
        });
        if (!active) {
          stream.getTracks().forEach(t => t.stop());
          return;
        }
        streamRef.current = stream;
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          videoRef.current.play();
        }

        // Start scanning if BarcodeDetector is available
        if (isBarcodeDetectorSupported) {
          // @ts-ignore
          const barcodeDetector = new (window as any).BarcodeDetector({
            formats: ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128', 'qr_code']
          });

          const scanInterval = setInterval(async () => {
            if (!active || !videoRef.current) return;
            try {
              if (videoRef.current.readyState === videoRef.current.HAVE_ENOUGH_DATA) {
                const barcodes = await barcodeDetector.detect(videoRef.current);
                if (barcodes.length > 0 && barcodes[0].rawValue) {
                  clearInterval(scanInterval);
                  const scanned = barcodes[0].rawValue;
                  toast.success(`Barcode scanned: ${scanned}`);
                  onScan(scanned);
                  onClose();
                }
              }
            } catch {
              // Frame scan error
            }
          }, 250);

          return () => clearInterval(scanInterval);
        }
      } catch (err: any) {
        console.warn('Camera access denied or unavailable:', err);
        setHasCamera(false);
        setCameraError('Camera access unavailable. You can type or use a USB handheld barcode reader below.');
      }
    };

    startCamera();

    return () => {
      active = false;
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(t => t.stop());
      }
    };
  }, [isOpen, onScan, onClose]);

  // Handle manual / USB scanner Enter key
  const handleManualSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (manualCode.trim()) {
      onScan(manualCode.trim());
      toast.success(`Barcode recorded: ${manualCode.trim()}`);
      onClose();
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal-overlay" onClick={onClose} style={{ zIndex: 1100 }}>
      <motion.div
        className="modal-dialog"
        initial={{ scale: 0.95, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        exit={{ scale: 0.95, opacity: 0 }}
        onClick={e => e.stopPropagation()}
        style={{ maxWidth: 440, width: '90%' }}
      >
        <div className="drawer-header" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <h3 style={{ margin: 0, fontSize: 16, display: 'flex', alignItems: 'center', gap: 8 }}>
            <FaBarcode color="var(--brand-primary)" /> Scan Product Barcode
          </h3>
          <button onClick={onClose} className="btn btn-ghost" style={{ padding: 6 }}>
            <FaTimes />
          </button>
        </div>

        <div style={{ padding: '20px 24px', display: 'flex', flexDirection: 'column', gap: 16 }}>
          {/* Camera Viewfinder */}
          {hasCamera ? (
            <div style={{
              position: 'relative',
              width: '100%',
              height: 220,
              borderRadius: 'var(--radius-md)',
              overflow: 'hidden',
              background: '#000',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <video
                ref={videoRef}
                style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                muted
                playsInline
              />
              {/* Scan target box overlay */}
              <div style={{
                position: 'absolute',
                width: '70%',
                height: 100,
                border: '2px dashed #1BA672',
                borderRadius: 8,
                boxShadow: '0 0 0 9999px rgba(0, 0, 0, 0.45)',
                pointerEvents: 'none',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center'
              }}>
                <div style={{ height: 2, width: '90%', background: '#EF4444', opacity: 0.8, animation: 'pulse 1.5s infinite' }} />
              </div>
            </div>
          ) : (
            <div style={{
              padding: 16,
              background: 'var(--bg-surface-elevated)',
              border: '1px solid var(--border)',
              borderRadius: 'var(--radius-md)',
              fontSize: 13,
              color: 'var(--text-secondary)'
            }}>
              <FaCamera style={{ marginRight: 6, color: 'var(--text-muted)' }} />
              {cameraError}
            </div>
          )}

          {/* USB Scanner or Manual Input */}
          <form onSubmit={handleManualSubmit}>
            <label className="form-label" style={{ fontSize: 12, marginBottom: 4, display: 'flex', alignItems: 'center', gap: 6 }}>
              <FaKeyboard /> USB Scanner or Manual Entry
            </label>
            <div style={{ display: 'flex', gap: 8 }}>
              <input
                autoFocus
                value={manualCode}
                onChange={e => setManualCode(e.target.value)}
                placeholder="Scan with handheld reader or type barcode..."
                style={{ flex: 1 }}
              />
              <button type="submit" className="btn btn-primary" disabled={!manualCode.trim()}>
                Apply
              </button>
            </div>
            <span style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4, display: 'block' }}>
              Handheld USB scanners work like a keyboard. Just pull the trigger while this box is active.
            </span>
          </form>
        </div>

        <div className="drawer-footer" style={{ display: 'flex', justifyContent: 'flex-end' }}>
          <button onClick={onClose} className="btn btn-ghost">Cancel</button>
        </div>
      </motion.div>
    </div>
  );
};

export default BarcodeScannerModal;
