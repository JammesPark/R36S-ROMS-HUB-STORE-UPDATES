#!/usr/bin/env python3
"""Teste sem rede dos comandos de pausa, retomada e cancelamento de ROMs/temas."""
import importlib.util
import json
import pathlib
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


rom = module('rom_source_controls', ROOT/'port/r36s-roms-store/bin/gamestore_source.py')
theme = module('theme_source_controls', ROOT/'port/r36s-roms-store/bin/es_theme_manager.py')

with tempfile.TemporaryDirectory(prefix='roms-control-test-') as td:
    root = pathlib.Path(td)
    sentinel = root/'favorites.json'
    sentinel.write_text('{"keep":true}')
    events = []

    control_rom = root/'roms.json'
    rom.CONTROL = str(control_rom)
    rom.status = lambda phase, message, **kwargs: events.append(('rom', phase, kwargs))
    rom.check_transfer_control('Teste ROM', 1024, 8192)
    control_rom.write_text('{"action":"cancel"}')
    try:
        rom.check_transfer_control('Teste ROM', 1024, 8192)
    except rom.TransferCancelled:
        pass
    else:
        raise AssertionError('ROM cancel was not honored')
    control_rom.write_text('{"action":"pause"}')
    old_sleep = rom.time.sleep
    calls = [0]

    def resume_rom(seconds):
        calls[0] += 1
        control_rom.write_text('{"action":"resume"}')

    rom.time.sleep = resume_rom
    try:
        rom.check_transfer_control('Teste ROM', 3000, 8192)
    finally:
        rom.time.sleep = old_sleep
    assert calls[0] == 1
    assert [e[1] for e in events[-2:]] == ['paused', 'downloading']

    control_theme = root/'themes.json'
    theme.CONTROL = control_theme
    theme.output = lambda phase, message, **kwargs: events.append(('theme', phase, kwargs))
    theme.wait_for_transfer_control(0, 8192)
    control_theme.write_text('{"action":"cancel"}')
    try:
        theme.wait_for_transfer_control(1024, 8192)
    except theme.TransferCancelled:
        pass
    else:
        raise AssertionError('Theme cancel was not honored')
    control_theme.write_text('{"action":"pause"}')
    original_sleep = theme.time.sleep

    def resume_theme(seconds):
        control_theme.write_text('{"action":"resume"}')

    theme.time.sleep = resume_theme
    try:
        theme.wait_for_transfer_control(1024, 8192)
    finally:
        theme.time.sleep = original_sleep
    assert [e[1] for e in events[-2:]] == ['paused', 'downloading']
    assert sentinel.read_text() == '{"keep":true}'
print('PASS ROM/theme pause, resume and cancel; unrelated user data unchanged')
