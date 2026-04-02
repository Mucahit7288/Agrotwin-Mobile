package com.agrotwin.backend.controller;

import com.agrotwin.backend.entity.EnergySchedule;
import com.agrotwin.backend.service.EnergyScheduleService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/energy-schedule")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class EnergyScheduleController {

    private final EnergyScheduleService energyScheduleService;

    @GetMapping
    public ResponseEntity<List<EnergySchedule>> getAll() {
        return ResponseEntity.ok(energyScheduleService.getAll());
    }

    @GetMapping("/active")
    public ResponseEntity<List<EnergySchedule>> getActive() {
        return ResponseEntity.ok(energyScheduleService.getActive());
    }

    @GetMapping("/cihaz/{cihaz}")
    public ResponseEntity<List<EnergySchedule>> getByCihaz(@PathVariable String cihaz) {
        return ResponseEntity.ok(energyScheduleService.getByCihaz(cihaz));
    }

    @GetMapping("/{id}")
    public ResponseEntity<EnergySchedule> getById(@PathVariable Long id) {
        return energyScheduleService.getById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<EnergySchedule> create(@RequestBody EnergySchedule energySchedule) {
        return ResponseEntity.ok(energyScheduleService.save(energySchedule));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        energyScheduleService.deleteById(id);
        return ResponseEntity.noContent().build();
    }
}
