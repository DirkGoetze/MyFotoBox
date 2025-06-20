#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# test_manage_files.py - Test-Skript für die manage_files.py Funktionalität
# 
# Teil der Fotobox2 Anwendung
# Copyright (c) 2023-2025 Dirk Götze
#

import os
import sys
import unittest
import tempfile
import shutil

# Stelle sicher, dass das Hauptverzeichnis im Pythonpfad ist
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Importiere das zu testende Modul
from backend.manage_files import (
    get_config_file_path, get_system_file_path, get_log_file_path,
    get_template_file_path, file_exists, read_file_content, write_file_content
)

class TestManageFiles(unittest.TestCase):
    """Testfälle für manage_files.py"""
    
    def setUp(self):
        """Setup-Methode für die Tests"""
        # Erstelle ein temporäres Verzeichnis für Testdateien
        self.test_dir = tempfile.mkdtemp(prefix="fotobox_test_")
    
    def tearDown(self):
        """Cleanup nach den Tests"""
        # Temporäres Verzeichnis entfernen
        shutil.rmtree(self.test_dir, ignore_errors=True)
    
    def test_config_file_path(self):
        """Test für get_config_file_path"""
        # Test für nginx Konfiguration
        nginx_path = get_config_file_path("nginx", "fotobox")
        self.assertIsNotNone(nginx_path)
        self.assertTrue(nginx_path.endswith("fotobox.conf"))
        
        # Test für Kamera-Konfiguration
        camera_path = get_config_file_path("camera", "default")
        self.assertIsNotNone(camera_path)
        self.assertTrue(camera_path.endswith("default.json"))
        
        # Test für ungültige Kategorie
        with self.assertRaises(ValueError):
            get_config_file_path("invalid", "test")
    
    def test_system_file_path(self):
        """Test für get_system_file_path"""
        # Test für nginx-Systemdatei
        nginx_path = get_system_file_path("nginx", "fotobox")
        self.assertIsNotNone(nginx_path)
        self.assertTrue(nginx_path.endswith("fotobox.conf"))
        
        # Test für systemd-Service-Datei
        systemd_path = get_system_file_path("systemd", "fotobox-backend")
        self.assertIsNotNone(systemd_path)
        self.assertTrue(systemd_path.endswith("fotobox-backend.service"))
        
        # Test für ungültigen Dateityp
        with self.assertRaises(ValueError):
            get_system_file_path("invalid", "test")
    
    def test_log_file_path(self):
        """Test für get_log_file_path"""
        log_path = get_log_file_path("test")
        self.assertIsNotNone(log_path)
        self.assertTrue("test_" in log_path)
        self.assertTrue(log_path.endswith(".log"))
    
    def test_template_file_path(self):
        """Test für get_template_file_path"""
        # Test für nginx-Template
        template_path = get_template_file_path("nginx", "backup_file.meta.json")
        self.assertIsNotNone(template_path)
        self.assertTrue(template_path.endswith("template_backup_file.meta.json"))
        
        # Test für ungültige Kategorie
        with self.assertRaises(ValueError):
            get_template_file_path("invalid", "test")
    
    def test_file_operations(self):
        """Test für Dateioperationen (exists, read, write)"""
        test_file = os.path.join(self.test_dir, "test.txt")
        test_content = "Dies ist ein Test-Inhalt"
        
        # Datei erstellen
        self.assertTrue(write_file_content(test_file, test_content))
        
        # Prüfen, ob Datei existiert
        self.assertTrue(file_exists(test_file))
        
        # Inhalt lesen
        content = read_file_content(test_file)
        self.assertEqual(content, test_content)

if __name__ == "__main__":
    unittest.main()
