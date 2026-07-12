import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';
import { GymLeadForm } from './gym-lead-form/gym-lead-form';

@Component({
  selector: 'app-register-gym',
  imports: [RouterLink, GymLeadForm],
  templateUrl: './register-gym.html',
  styleUrl: './register-gym.scss',
})
export class RegisterGym {}
