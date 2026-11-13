'use client';

import { useEffect } from 'react';

const scripts = ['/assets/system.js', '/assets/motion/motion.js', '/assets/layout/layout.js'];

export default function Boot() {
  useEffect(() => {
    let i = 0;
    const next = () => {
      if (i >= scripts.length) return;
      const s = document.createElement('script');
      s.type = 'module';
      s.src = scripts[i++];
      s.onload = next;
      s.onerror = next;
      document.body.appendChild(s);
    };
    next();
  }, []);
  return null;
}
