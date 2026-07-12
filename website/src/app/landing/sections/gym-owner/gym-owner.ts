import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';
import { PhoneDemo } from '../../phone/phone-demo/phone-demo';

@Component({
  selector: 'app-gym-owner',
  imports: [RouterLink, PhoneDemo],
  templateUrl: './gym-owner.html',
  styleUrl: './gym-owner.scss',
})
export class GymOwner {}
